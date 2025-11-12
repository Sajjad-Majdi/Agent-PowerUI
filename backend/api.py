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
import sys
import warnings
import threading
import queue as queue_module


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

        def generate_response():
            import time
            try:
                agent_iter = online_agent.send_message(
                    message, session_id, cancel_event=cancel_event)
                threading.current_thread().cancel_event = cancel_event
                agent_done = False

                while not agent_done:
                    # Check cancellation immediately at the start of each iteration
                    if cancel_event.is_set():
                        print(
                            f"[API] Cancellation signal received for session {session_id}")
                        try:
                            agent_iter.close()
                        except Exception:
                            pass
                        yield json.dumps({'type': 'cancelled'}) + '\n'
                        return

                    # Try to get next agent message (non-blocking check)
                    try:
                        last_message = next(agent_iter)

                        if hasattr(last_message, 'tool_calls') and last_message.tool_calls:
                            for tool_call in last_message.tool_calls:
                                yield json.dumps({'type': 'tool_call', 'content': {'name': tool_call['name'], 'args': tool_call['args']}}) + '\n'

                        elif hasattr(last_message, 'content') and last_message.content:
                            if last_message.type == "human":
                                yield json.dumps({'type': 'user_message', 'content': last_message.content}) + '\n'
                            elif last_message.type == "ai":
                                yield json.dumps({'type': 'ai_message', 'content': last_message.content}) + '\n'
                            else:
                                normalized = normalize_tool_output(
                                    last_message.content)
                                yield json.dumps({
                                    'type': 'tool_message',
                                    'content': normalized
                                }) + '\n'

                    except StopIteration:
                        agent_done = True

                    # Always check for queued MCP progress updates
                    while not progress_queue.empty():
                        try:
                            progress_event = progress_queue.get_nowait()
                            yield json.dumps(progress_event) + '\n'
                        except queue_module.Empty:
                            break

                    # Small sleep to allow queue updates
                    if not agent_done:
                        time.sleep(0.05)

                yield json.dumps({'type': 'complete'}) + '\n'

            except Exception as e:
                yield json.dumps({'type': 'error', 'content': str(e)}) + '\n'
            finally:
                if session_id in mcp_progress_queues:
                    del mcp_progress_queues[session_id]
                if session_id in session_cancel_events:
                    del session_cancel_events[session_id]
                if hasattr(threading.current_thread(), 'cancel_event'):
                    delattr(threading.current_thread(), 'cancel_event')

        return Response(generate_response(), mimetype='application/x-ndjson')

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
    # core tools
    tools_info = []
    if available_tools:
        for tool in available_tools:
            try:
                tools_info.append(
                    {'name': tool.name, 'description': getattr(tool, 'description', '')})
            except Exception:
                tools_info.append({'name': str(tool), 'description': ''})

    # Load MCP tools from configuration
    mcp = {'servers': []}
    try:
        from langchain_mcp_adapters.client import MultiServerMCPClient
        from langchain_mcp_adapters.tools import load_mcp_tools

        mcp_servers = Config.get_mcp_servers()
        mcp_state = Config.get_mcp_state()

        if mcp_servers:
            for server_name, server_config in mcp_servers.items():
                # Check if server is enabled in state
                is_enabled = mcp_state.get(server_name, True)

                # Get tool list by connecting briefly (only for UI display)
                tool_names = []
                try:
                    async def get_tool_names():
                        client = MultiServerMCPClient(
                            {server_name: server_config})
                        async with client.session(server_name) as session:
                            tools = await load_mcp_tools(session)
                            return [tool.name for tool in tools]

                    tool_names = asyncio.run(get_tool_names())
                except Exception as e:
                    print(f"Error loading tools from {server_name}: {e}")
                    tool_names = []

                mcp['servers'].append({
                    'name': server_name,
                    'enabled': is_enabled,
                    'tools': [{'name': name} for name in tool_names]
                })
    except Exception as e:
        print(f"Error loading MCP tools: {e}")
        pass

    return jsonify({'tools': tools_info, 'mcp': mcp})


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


@app.route('/api/mcp/toggle', methods=['POST'])
def toggle_mcp_server():
    """Toggle an MCP server on or off"""
    try:
        data = request.json or {}
        server_name = data.get('server_name')
        enabled = data.get('enabled')

        if server_name is None or enabled is None:
            return jsonify({'error': 'server_name and enabled are required'}), 400

        # Get current state
        mcp_state = Config.get_mcp_state()

        # Update the state
        mcp_state[server_name] = enabled

        # Save the state
        Config.set_mcp_state(mcp_state)

        # No need to reload tools - browse_web checks enabled state at runtime
        print(f"MCP server '{server_name}' toggled to {enabled}")

        return jsonify({'message': f"MCP server '{server_name}' toggled successfully", 'enabled': enabled})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    status = get_local_agent_status()
    return jsonify({
        'status': 'healthy',
        'online_agent_initialized': online_agent is not None,
        'local_agent_initialized': status.get('running', False)
    })


if __name__ == '__main__':
    print("Starting Flask server...")
    online_agent = asyncio.run(init_online_agent())
    app.run(debug=True, host='0.0.0.0', port=5000, use_reloader=False)
