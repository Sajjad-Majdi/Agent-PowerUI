from mcp_agent import generate_mcp_agent_metadata
from tools import MCP_TOOL_REGISTRY
from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from config import Config
from utils import (
    initialize_local_agent as init_local_agent,
    initialize_online_agent as init_online_agent,
    list_chat_sessions_named,
    get_session_messages,
    delete_session as delete_session_util,
    normalize_tool_output,
    list_local_models,
    stop_local_agent as stop_local_agent_util,
    get_local_agent,
    get_local_agent_status,
)
import json
import asyncio
import os
import shutil
import sys
import warnings
import threading
import queue as queue_module
import atexit

from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_mcp_adapters.tools import load_mcp_tools

try:  # Python 3.11+
    from builtins import BaseExceptionGroup as _BaseExceptionGroup
except ImportError:  # pragma: no cover - older Python
    _BaseExceptionGroup = BaseException  # type: ignore[misc]


def _summarize_exception(exc: Exception) -> str:
    """Return the most helpful message from nested MCP connection errors."""

    from httpx import HTTPStatusError

    if isinstance(exc, _BaseExceptionGroup):
        for sub in getattr(exc, "exceptions", []):
            message = _summarize_exception(sub)  # type: ignore[arg-type]
            if message:
                return message
        return str(exc)

    cause = exc.__cause__ or exc.__context__
    if cause:
        return _summarize_exception(cause)

    if isinstance(exc, HTTPStatusError):
        status = exc.response.status_code
        reason = exc.response.reason_phrase or ""
        hint = " – check credentials or headers" if status in (
            401, 403) else ""
        return f"HTTP {status} {reason}{hint}"

    return str(exc)


class _SafeStream:
    """Wrap a text stream so that OSError writes are silently ignored."""

    def __init__(self, wrapped):
        self._wrapped = wrapped

    def write(self, data):
        try:
            return self._wrapped.write(data)
        except OSError:
            return len(data)

    def flush(self):
        try:
            return self._wrapped.flush()
        except OSError:
            return None

    def __getattr__(self, item):
        return getattr(self._wrapped, item)


sys.stdout = _SafeStream(sys.stdout)
sys.stderr = _SafeStream(sys.stderr)

# Suppress MCP schema warnings
warnings.filterwarnings('ignore')
os.environ['PYTHONWARNINGS'] = 'ignore'

app = Flask(__name__)
CORS(app)


# Global agent instances
online_agent = None
available_tools = Config.get_default_tools()

# Global queue for MCP progress streaming
mcp_progress_queues = {}
# Cancellation events per session
session_cancel_events = {}


def cleanup_on_exit():
    try:
        for _, event in list(session_cancel_events.items()):
            try:
                event.set()
            except Exception:
                pass
    except Exception:
        pass
    try:
        stop_local_agent_util()
    except Exception:
        pass


atexit.register(cleanup_on_exit)


def refresh_available_tools():
    global available_tools, online_agent
    available_tools = Config.get_default_tools()
    if online_agent is not None:
        try:
            online_agent.update_tools(available_tools)
        except Exception as exc:
            print(f"[API] Failed to refresh online agent tools: {exc}")


def _load_mcp_server_tools(server_name: str, server_config: dict):
    async def _load():
        client = MultiServerMCPClient({server_name: server_config})
        async with client.session(server_name) as session:
            tools = await load_mcp_tools(session)
            snapshot = []
            for tool in tools:
                snapshot.append({
                    'name': tool.name,
                    'description': getattr(tool, 'description', '') or ''
                })
            return snapshot

    try:
        return asyncio.run(_load())
    except Exception as exc:  # noqa: BLE001 - convert to clearer message
        message = _summarize_exception(exc)
        raise RuntimeError(message) from exc


@app.route('/api/chat', methods=['POST'])
def chat():
    """Handle online chat messages with Gemini"""
    data = request.json
    message = data.get('message', '')
    session_id = data.get('session_id', 'default_session')

    if not message:
        return jsonify({'error': 'Message is required'}), 400

    if not online_agent:
        return jsonify({'error': 'Online agent not initialized'}), 500

    try:
        progress_queue = queue_module.Queue()
        mcp_progress_queues[session_id] = progress_queue
        cancel_event = threading.Event()
        session_cancel_events[session_id] = cancel_event
        try:
            import tools as _tools
            _tools.CURRENT_SESSION_ID = session_id
            _tools.CURRENT_PROGRESS_QUEUE = progress_queue
            _tools.CURRENT_CANCEL_EVENT = cancel_event
        except Exception:
            pass

        # Shared state for communication between threads
        response_queue = queue_module.Queue()  # For sending responses to be yielded
        agent_finished = threading.Event()

        def agent_worker():
            """Run agent in a separate thread, putting results in response_queue."""
            # Ensure thread-local context for downstream MCP tool execution
            current_thread = threading.current_thread()
            setattr(current_thread, 'session_id', session_id)
            setattr(current_thread, 'cancel_event', cancel_event)
            try:
                agent_iter = online_agent.send_message(
                    message, session_id, cancel_event=cancel_event)

                for last_message in agent_iter:
                    if cancel_event.is_set():
                        response_queue.put({'type': 'cancelled'})
                        return

                    if hasattr(last_message, 'tool_calls') and last_message.tool_calls:
                        for tool_call in last_message.tool_calls:
                            response_queue.put({'type': 'tool_call', 'content': {
                                               'name': tool_call['name'], 'args': tool_call['args']}})
                    if hasattr(last_message, 'content') and last_message.content:
                        if last_message.type == "human":
                            response_queue.put(
                                {'type': 'user_message', 'content': last_message.content})
                        elif last_message.type == "ai":
                            response_queue.put(
                                {'type': 'ai_message', 'content': last_message.content})
                        else:
                            normalized = normalize_tool_output(
                                last_message.content)
                            response_queue.put(
                                {'type': 'tool_message', 'content': normalized})

                response_queue.put({'type': 'complete'})
            except Exception as e:
                response_queue.put({'type': 'error', 'content': str(e)})
            finally:
                agent_finished.set()
                # Clean up thread-local attributes
                if hasattr(current_thread, 'session_id'):
                    delattr(current_thread, 'session_id')
                if hasattr(current_thread, 'cancel_event'):
                    delattr(current_thread, 'cancel_event')

        def generate_response():
            import time

            # Start agent in background thread
            agent_thread = threading.Thread(target=agent_worker, daemon=True)
            agent_thread.start()

            try:
                while not agent_finished.is_set() or not response_queue.empty() or not progress_queue.empty():
                    # Check cancellation
                    if cancel_event.is_set() and response_queue.empty():
                        yield json.dumps({'type': 'cancelled'}) + '\n'
                        break

                    # Drain progress queue first (MCP real-time updates)
                    while not progress_queue.empty():
                        try:
                            progress_event = progress_queue.get_nowait()
                            yield json.dumps(progress_event) + '\n'
                        except queue_module.Empty:
                            break

                    # Check response queue
                    try:
                        response_event = response_queue.get(timeout=0.05)
                        yield json.dumps(response_event) + '\n'

                        if response_event.get('type') in ('complete', 'error', 'cancelled'):
                            break
                    except queue_module.Empty:
                        pass

                # Final drain of progress queue
                while not progress_queue.empty():
                    try:
                        progress_event = progress_queue.get_nowait()
                        yield json.dumps(progress_event) + '\n'
                    except queue_module.Empty:
                        break

            except Exception as e:
                yield json.dumps({'type': 'error', 'content': str(e)}) + '\n'
            finally:
                # Wait for agent thread to finish (with timeout)
                agent_thread.join(timeout=1.0)

                if session_id in mcp_progress_queues:
                    del mcp_progress_queues[session_id]
                if session_id in session_cancel_events:
                    del session_cancel_events[session_id]
                try:
                    import tools as _tools
                    if getattr(_tools, 'CURRENT_SESSION_ID', None) == session_id:
                        _tools.CURRENT_SESSION_ID = None
                        _tools.CURRENT_PROGRESS_QUEUE = None
                        _tools.CURRENT_CANCEL_EVENT = None
                except Exception:
                    pass

        response = Response(generate_response(),
                            mimetype='application/x-ndjson')
        # Optional headers to discourage buffering and improve real-time streaming
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['X-Accel-Buffering'] = 'no'
        return response

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/chat/local', methods=['POST'])
def chat_local():
    """Handle local chat messages with llama.cpp"""
    data = request.json
    message = data.get('message', '')
    session_id = data.get('session_id', 'default_session')

    if not message:
        return jsonify({'error': 'Message is required'}), 400

    agent = get_local_agent()
    if not agent or not agent.is_running():
        return jsonify({'error': 'Local agent not initialized'}), 500

    try:
        def generate_response():
            try:
                for last_message in agent.send_message(message, session_id):

                    if hasattr(last_message, 'tool_calls') and last_message.tool_calls:
                        for tool_call in last_message.tool_calls:
                            yield json.dumps({'type': 'tool_call', 'content': {'name': tool_call['name'], 'args': tool_call['args']}}) + '\n'

                    elif hasattr(last_message, 'content') and last_message.content:
                        if last_message.type == "human":
                            continue
                        elif last_message.type == "ai":
                            content_str = str(last_message.content).lower()
                            if ('result 1' in content_str and ('result 2' in content_str or 'result 3' in content_str)) or \
                               ('search result' in content_str and 'result 1' in content_str):
                                continue
                            else:
                                yield json.dumps({'type': 'ai_message', 'content': last_message.content}) + '\n'
                        else:
                            yield json.dumps({'type': 'tool_message', 'content': last_message.content}) + '\n'

                yield json.dumps({'type': 'complete'}) + '\n'

            except Exception as e:
                yield json.dumps({'type': 'error', 'content': str(e)}) + '\n'

        return Response(generate_response(), mimetype='application/x-ndjson')

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/chat/stop', methods=['POST'])
def stop_chat():
    """Signal cancellation for a running chat session"""
    data = request.json or {}
    session_id = data.get('session_id') or 'default_session'

    event = session_cancel_events.get(session_id)
    if event is None:
        return jsonify({'status': 'idle'})

    event.set()
    # Clear MCP progress queue entry if present to unblock producers
    progress_queue = mcp_progress_queues.get(session_id)
    if progress_queue is not None:
        try:
            progress_queue.put_nowait({'type': 'cancelled'})
        except queue_module.Full:
            pass

    return jsonify({'status': 'stopping'})


@app.route('/api/local/start', methods=['POST'])
def start_local_agent_route():
    """Start the local llama.cpp server with selected model"""
    data = request.json or {}
    model = data.get('model')
    print(f"[API] Starting local agent with model: {model}")
    try:
        init_local_agent(model_name=model)
        print(f"[API] Local agent started successfully")
        status = get_local_agent_status()
        print(f"[API] Status: {status}")
        return jsonify(status), 200
    except ValueError as e:
        print(f"[API] ValueError: {e}")
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        print(f"[API] Exception: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/api/local/stop', methods=['POST'])
def stop_local_agent_route():
    """Stop the running local llama.cpp server if active"""
    try:
        stop_local_agent_util()
        status = get_local_agent_status()
        return jsonify(status), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/local/status', methods=['GET'])
def local_agent_status_route():
    """Return current status for the local llama.cpp server"""
    try:
        status = get_local_agent_status()
        return jsonify(status), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/tools', methods=['GET'])
def get_tools():
    """Get available core tools and MCP tools grouped by server"""
    tools_info = []
    for tool in available_tools:
        try:
            name = getattr(tool, 'name', str(tool))
            description = getattr(tool, 'description', '') or ''
            entry = {'name': name, 'description': description}

            registry_entry = MCP_TOOL_REGISTRY.get(name)
            if registry_entry:
                entry['mcp'] = True
                entry['server_name'] = registry_entry.get('server_name')
                entry['display_name'] = registry_entry.get(
                    'display_name', name)
                entry['metadata'] = registry_entry.get('metadata') or {}

            tools_info.append(entry)
        except Exception:
            tools_info.append({'name': str(tool), 'description': ''})

    agents_payload = []
    for agent in Config.list_mcp_agents():
        metadata = agent.get('metadata') or {}
        agents_payload.append({
            'server_name': agent['name'],
            'config': agent['config'],
            'metadata': metadata,
            'tools': metadata.get('tools', []),
            'status': metadata.get('status', 'pending_metadata'),
            'last_error': metadata.get('last_error'),
        })

    return jsonify({'tools': tools_info, 'mcp': {'agents': agents_payload}})


@app.route('/api/memory', methods=['GET'])
def get_memory_data():
    """Get memory data for display"""
    try:
        memory_path = Config.memory_path
        os.makedirs(os.path.dirname(memory_path), exist_ok=True)
        if not os.path.exists(memory_path):
            with open(memory_path, 'w') as f:
                json.dump({}, f)
        with open(memory_path, "r") as f:
            try:
                memory = json.load(f)
            except json.JSONDecodeError:
                memory = {}
        return jsonify({'memory': memory})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/memory/<string:category>/<int:fact_id>', methods=['DELETE'])
def delete_memory_fact(category, fact_id):
    """Delete a specific fact from memory"""
    try:
        memory_path = Config.memory_path
        if not os.path.exists(memory_path):
            return jsonify({'error': 'Memory file not found'}), 404

        with open(memory_path, "r") as f:
            memory = json.load(f)

        if category not in memory:
            return jsonify({'error': 'Category not found'}), 404

        # Find and remove the fact
        original_length = len(memory[category])
        memory[category] = [fact for fact in memory[category]
                            if fact.get('id') != fact_id]

        if len(memory[category]) == original_length:
            return jsonify({'error': 'Fact not found'}), 404

        # Remove category if empty
        if not memory[category]:
            del memory[category]

        # Save back to file
        with open(memory_path, "w") as f:
            json.dump(memory, f, indent=4)

        return jsonify({'message': 'Fact deleted successfully'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/list_chat_sessions', methods=['GET'])
def get_chat_sessions():
    """List all chat sessions"""
    try:
        sessions = list_chat_sessions_named(online_agent)
        return jsonify({'sessions': sessions})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/load_session/<string:session_id>', methods=['GET'])
def load_session_route(session_id):
    """Load messages from a specific session"""
    try:
        messages = get_session_messages(session_id, online_agent)
        return jsonify({'messages': messages})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/delete_session/<string:session_id>', methods=['DELETE'])
def delete_session_route(session_id):
    """Delete a specific session"""
    try:
        success = delete_session_util(session_id)
        if success:
            return jsonify({'message': f"session '{session_id}' deleted successfully"}), 200
        else:
            return jsonify({'error': f"session '{session_id}' not found"}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/list_models', methods=['GET'])
def list_models():
    """List all available local models"""
    try:
        models = list_local_models()
        status = get_local_agent_status()
        return jsonify({'models': models, 'status': status})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/gemini_models', methods=['GET'])
def gemini_models():
    """List available Gemini models from config with active model highlighted"""
    try:
        models = Config.list_gemini_models()
        active = online_agent.model if online_agent is not None else Config.DEFAULT_GEMINI_MODEL
        return jsonify({'models': models, 'active': active})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/set_model', methods=['POST'])
def set_model():
    """Set active Gemini model for online agent"""
    try:
        data = request.json or {}
        model = data.get('model')
        if model not in Config.list_gemini_models():
            return jsonify({'error': 'Invalid model'}), 400
        if online_agent is None:
            return jsonify({'error': 'Online agent not initialized'}), 500
        new_model = online_agent.set_model(model)
        return jsonify({'model': new_model})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/mcp/agents', methods=['GET'])
def list_mcp_agents():
    agents = []
    for agent in Config.list_mcp_agents():
        metadata = agent.get('metadata') or {}
        agents.append({
            'server_name': agent['name'],
            'config': agent['config'],
            'metadata': metadata,
            'status': metadata.get('status', 'pending_metadata'),
            'last_error': metadata.get('last_error'),
        })
    return jsonify({'agents': agents})


@app.route('/api/mcp/agents', methods=['POST'])
def add_mcp_agent():
    data = request.json or {}
    server_name = (data.get('server_name') or '').strip()
    server_config = data.get('config') or {}
    provided_metadata = data.get('metadata')

    if not server_name:
        return jsonify({'error': 'server_name is required'}), 400

    # Validate config based on transport type
    if not isinstance(server_config, dict):
        return jsonify({'error': 'config must be a valid object'}), 400

    transport = server_config.get('transport', 'stdio')

    if transport == 'streamable_http':
        # Remote connection requires 'url'
        if not server_config.get('url'):
            return jsonify({'error': 'config.url is required for streamable_http transport'}), 400
    else:
        # Local connection requires 'command'
        if not server_config.get('command'):
            return jsonify({'error': 'config.command is required for stdio transport'}), 400

    existing_servers = Config.get_mcp_servers()
    if server_name in existing_servers:
        return jsonify({'error': f"Server '{server_name}' already exists"}), 409

    try:
        tools_snapshot = _load_mcp_server_tools(server_name, server_config)
    except Exception as exc:
        return jsonify({'error': f'Unable to connect to MCP server: {exc}'}), 400

    metadata_payload = None
    requires_manual = False

    try:
        if provided_metadata:
            for field in ('name', 'description', 'system_prompt'):
                value = (provided_metadata.get(field) or '').strip()
                if not value:
                    raise ValueError(f"metadata.{field} cannot be empty")
            metadata_payload = {
                'name': provided_metadata['name'].strip(),
                'description': provided_metadata['description'].strip(),
                'system_prompt': provided_metadata['system_prompt'].strip(),
                'tools': tools_snapshot,
                'status': 'ready',
                'source': provided_metadata.get('source', 'manual'),
                'last_error': None,
            }
        else:
            metadata_payload = generate_mcp_agent_metadata(
                server_name, tools_snapshot)
            metadata_payload.update({
                'tools': tools_snapshot,
                'status': 'ready',
                'source': 'gemini',
                'last_error': None,
            })
    except Exception as exc:
        metadata_payload = {
            'name': '',
            'description': '',
            'system_prompt': '',
            'tools': tools_snapshot,
            'status': 'pending_metadata',
            'source': 'manual',
            'last_error': str(exc),
        }
        requires_manual = True

    Config.set_mcp_server(server_name, server_config)
    Config.upsert_mcp_agent_metadata(server_name, metadata_payload)
    refresh_available_tools()

    stored_metadata = Config.get_mcp_agent_metadata(server_name) or {}
    response_payload = {
        'server_name': server_name,
        'config': server_config,
        'metadata': stored_metadata,
        'status': stored_metadata.get('status', 'pending_metadata'),
        'requires_manual_metadata': requires_manual,
    }

    return jsonify(response_payload), 201


@app.route('/api/mcp/agents/<string:server_name>/metadata', methods=['PUT'])
def update_mcp_agent_metadata(server_name: str):
    data = request.json or {}
    name = (data.get('name') or '').strip()
    description = (data.get('description') or '').strip()
    system_prompt = (data.get('system_prompt') or '').strip()

    if not all([name, description, system_prompt]):
        return jsonify({'error': 'name, description, and system_prompt are required'}), 400

    servers = Config.get_mcp_servers()
    if server_name not in servers:
        return jsonify({'error': f"Server '{server_name}' not found"}), 404

    metadata = Config.get_mcp_agent_metadata(server_name) or {}
    metadata.update({
        'name': name,
        'description': description,
        'system_prompt': system_prompt,
        'status': 'ready',
        'source': data.get('source', metadata.get('source', 'manual')),
        'last_error': None,
    })
    if 'tools' not in metadata or not metadata['tools']:
        try:
            metadata['tools'] = _load_mcp_server_tools(
                server_name, servers[server_name])
        except Exception as exc:
            metadata['tools'] = []
            metadata['last_error'] = f'Failed to refresh MCP tools: {exc}'
            metadata['status'] = 'pending_metadata'

    Config.upsert_mcp_agent_metadata(server_name, metadata)
    refresh_available_tools()

    stored = Config.get_mcp_agent_metadata(server_name) or {}
    return jsonify({
        'server_name': server_name,
        'metadata': stored,
        'status': stored.get('status', 'pending_metadata')
    })


@app.route('/api/mcp/agents/<string:server_name>/regenerate', methods=['POST'])
def regenerate_mcp_agent_metadata(server_name: str):
    servers = Config.get_mcp_servers()
    if server_name not in servers:
        return jsonify({'error': f"Server '{server_name}' not found"}), 404

    try:
        tools_snapshot = _load_mcp_server_tools(
            server_name, servers[server_name])
        metadata = generate_mcp_agent_metadata(server_name, tools_snapshot)
        metadata.update({
            'tools': tools_snapshot,
            'status': 'ready',
            'source': 'gemini',
            'last_error': None,
        })
        Config.upsert_mcp_agent_metadata(server_name, metadata)
        refresh_available_tools()
        stored = Config.get_mcp_agent_metadata(server_name) or {}
        return jsonify({
            'server_name': server_name,
            'metadata': stored,
            'status': stored.get('status', 'pending_metadata')
        })
    except Exception as exc:
        return jsonify({'error': str(exc)}), 500


@app.route('/api/mcp/agents/<string:server_name>', methods=['DELETE'])
def delete_mcp_agent(server_name: str):
    servers = Config.get_mcp_servers()
    if server_name not in servers:
        return jsonify({'error': f"Server '{server_name}' not found"}), 404

    Config.remove_mcp_server(server_name)
    refresh_available_tools()

    return jsonify({'message': f"MCP agent '{server_name}' deleted"})


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    status = get_local_agent_status()
    return jsonify({
        'status': 'healthy',
        'online_agent_initialized': online_agent is not None,
        'local_agent_initialized': status.get('running', False)
    })


@app.route('/api/instructions', methods=['GET'])
def get_instructions():
    """Get saved agent instructions"""
    try:
        instructions = Config.get_instructions()
        return jsonify({'instructions': instructions})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/instructions', methods=['POST'])
def set_instructions():
    """Save agent instructions"""
    try:
        data = request.json or {}
        instructions = data.get('instructions', '')
        Config.set_instructions(instructions)
        return jsonify({'message': 'Instructions saved successfully'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/gemini_api_key', methods=['GET'])
def get_gemini_api_key():
    """Get saved Gemini API key status (masked)"""
    try:
        api_key = Config.get_gemini_api_key()
        has_key = bool(api_key)
        masked_key = ''
        if has_key and len(api_key) > 8:
            masked_key = api_key[:4] + '...' + api_key[-4:]
        elif has_key:
            masked_key = '****'
        return jsonify({'has_key': has_key, 'masked_key': masked_key})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/gemini_api_key', methods=['POST'])
def set_gemini_api_key():
    """Save Gemini API key and reinitialize online agent"""
    try:
        data = request.json or {}
        api_key = data.get('api_key', '').strip()

        if not api_key:
            return jsonify({'error': 'API key is required'}), 400

        # Save the key
        Config.set_gemini_api_key(api_key)

        # Update environment variable for immediate use
        os.environ['GOOGLE_API_KEY'] = api_key

        # Reinitialize online agent with new key
        global online_agent
        try:
            from utils import initialize_online_agent
            online_agent = asyncio.run(initialize_online_agent())
            return jsonify({'message': 'API key saved and agent reinitialized successfully'})
        except Exception as e:
            return jsonify({'error': f'API key saved but agent initialization failed: {str(e)}'}), 500

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/paths', methods=['GET'])
def get_path_config():
    """Return current model and binary paths along with defaults"""
    try:
        return jsonify(Config.get_path_config())
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/paths', methods=['POST'])
def set_path_config():
    """Update model folder or llama.cpp binary path overrides"""
    try:
        data = request.json or {}
        if 'models_folder' in data:
            Config.set_models_folder(data.get('models_folder') or '')
        if 'llama_server_path' in data:
            Config.set_llama_server_path(data.get('llama_server_path') or '')

        return jsonify(Config.get_path_config())
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/models/import', methods=['POST'])
def import_local_model_route():
    """Copy a local .gguf file into the configured models folder."""
    try:
        data = request.json or {}
        source_path = data.get('path')

        print(f"[API] Import request received")
        print(f"[API] Source path: {source_path}")

        if not source_path:
            print(f"[API] Error: No path provided")
            return jsonify({'error': 'path is required'}), 400

        if not os.path.isfile(source_path):
            print(f"[API] Error: File not found at {source_path}")
            print(f"[API] File exists check: {os.path.exists(source_path)}")
            print(f"[API] Is file check: {os.path.isfile(source_path)}")
            return jsonify({'error': f'File not found: {source_path}'}), 404

        if not source_path.lower().endswith('.gguf'):
            print(f"[API] Error: Not a .gguf file")
            return jsonify({'error': 'File must be a .gguf model'}), 400

        destination_dir = Config.get_models_folder()
        print(f"[API] Destination directory: {destination_dir}")
        os.makedirs(destination_dir, exist_ok=True)

        filename = os.path.basename(source_path)
        name, ext = os.path.splitext(filename)
        dest_path = os.path.join(destination_dir, filename)
        counter = 1
        while os.path.exists(dest_path):
            dest_path = os.path.join(destination_dir, f"{name}_{counter}{ext}")
            counter += 1

        print(f"[API] Copying {source_path} -> {dest_path}")
        shutil.copy2(source_path, dest_path)
        print(f"[API] Copy successful!")

        return jsonify({
            'message': 'Model imported',
            'filename': os.path.basename(dest_path),
            'destination': dest_path,
        })
    except Exception as e:
        print(f"[API] Exception during import: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/api/models/delete', methods=['POST'])
def delete_local_model_route():
    """Delete a local .gguf file from the configured models folder."""
    try:
        data = request.json or {}
        model_name = data.get('name')

        print(f"[API] Delete request received for model: {model_name}")

        if not model_name:
            print(f"[API] Error: No model name provided")
            return jsonify({'error': 'name is required'}), 400

        models_dir = Config.get_models_folder()
        model_path = os.path.join(models_dir, model_name)

        print(f"[API] Model path: {model_path}")

        if not os.path.isfile(model_path):
            print(f"[API] Error: Model file not found at {model_path}")
            return jsonify({'error': f'Model not found: {model_name}'}), 404

        if not model_path.lower().endswith('.gguf'):
            print(f"[API] Error: Not a .gguf file")
            return jsonify({'error': 'File must be a .gguf model'}), 400

        # Check if model is currently running
        try:
            local_agent_status = get_local_agent_status()
            if local_agent_status.get('running') and local_agent_status.get('model') == model_name:
                print(f"[API] Error: Model is currently running")
                return jsonify({'error': 'Cannot delete a running model. Please stop it first.'}), 400
        except Exception as status_err:
            print(
                f"[API] Warning: Could not check local agent status: {status_err}")

        print(f"[API] Deleting {model_path}")
        os.remove(model_path)
        print(f"[API] Delete successful!")

        return jsonify({
            'message': 'Model deleted successfully',
            'name': model_name,
        })
    except Exception as e:
        print(f"[API] Exception during delete: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


def cleanup_on_exit():
    """Cleanup function to stop agents when the backend shuts down"""
    print("Shutting down backend, cancelling all sessions...")
    # Set cancel event for all active sessions
    for session_id, event in session_cancel_events.items():
        event.set()

    # Stop local agent process if running
    try:
        from utils import stop_local_agent
        stop_local_agent()
    except:
        pass


atexit.register(cleanup_on_exit)

if __name__ == '__main__':
    print("Starting Flask server...")

    # Set API key from config before initializing agent
    api_key = Config.get_gemini_api_key()
    if api_key:
        os.environ['GOOGLE_API_KEY'] = api_key
        print("Loaded Gemini API key from config")
    elif not os.environ.get('GOOGLE_API_KEY'):
        print("WARNING: No Gemini API key found. Set GOOGLE_API_KEY or configure via settings.")

    online_agent = asyncio.run(init_online_agent())
    refresh_available_tools()
    app.run(debug=True, host='0.0.0.0', port=5000, use_reloader=False)
