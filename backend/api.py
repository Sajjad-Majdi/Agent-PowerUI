from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from core.config import Config
from core.utils import (
    initialize_local_agent as init_local_agent,
    initialize_online_agent as init_online_agent,
    list_chat_sessions_named,
    get_session_messages,
    delete_session as delete_session_util,
)
import json
import asyncio
import os
import warnings

# Suppress MCP schema warnings
warnings.filterwarnings('ignore')
os.environ['PYTHONWARNINGS'] = 'ignore'

app = Flask(__name__)
CORS(app)


# Global agent instances
online_agent = None
local_agent = None
available_tools = Config.get_default_tools()


@app.route('/api/chat', methods=['POST'])
def chat():
    """Handle online chat messages with Gemini"""
    data = request.json
    message = data.get('message', '')
    session_id = data.get('session_id', 'default_session')
    system_prompt = data.get('system_prompt', Config.get_system_prompt())

    if not message:
        return jsonify({'error': 'Message is required'}), 400

    if not online_agent:
        return jsonify({'error': 'Online agent not initialized'}), 500

    try:
        def generate_response():
            try:
                for last_message in online_agent.send_message(message, session_id, system_prompt):

                    if hasattr(last_message, 'tool_calls') and last_message.tool_calls:
                        for tool_call in last_message.tool_calls:
                            yield f"data: {json.dumps({'type': 'tool_call', 'content': {'name': tool_call['name'], 'args': tool_call['args']}})}\n\n"

                    elif hasattr(last_message, 'content') and last_message.content:
                        if last_message.type == "human":
                            yield f"data: {json.dumps({'type': 'user_message', 'content': last_message.content})}\n\n"
                        else:
                            content_str = str(last_message.content).lower()
                            if ('result 1' in content_str and ('result 2' in content_str or 'result 3' in content_str)) or \
                               ('search result' in content_str and 'result 1' in content_str):
                                continue
                            else:
                                yield f"data: {json.dumps({'type': 'ai_message', 'content': last_message.content})}\n\n"

                yield f"data: {json.dumps({'type': 'complete'})}\n\n"

            except Exception as e:
                yield f"data: {json.dumps({'type': 'error', 'content': str(e)})}\n\n"

        return Response(generate_response(), mimetype='text/event-stream')

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/chat/local', methods=['POST'])
def chat_local():
    """Handle local chat messages with llama.cpp"""
    data = request.json
    message = data.get('message', '')
    session_id = data.get('session_id', 'default_session')
    system_prompt = data.get('system_prompt', Config.get_system_prompt())

    if not message:
        return jsonify({'error': 'Message is required'}), 400

    if not local_agent:
        return jsonify({'error': 'Local agent not initialized'}), 500

    try:
        def generate_response():
            try:
                for last_message in local_agent.send_message(message, session_id, system_prompt):

                    if hasattr(last_message, 'tool_calls') and last_message.tool_calls:
                        for tool_call in last_message.tool_calls:
                            yield f"data: {json.dumps({'type': 'tool_call', 'content': {'name': tool_call['name'], 'args': tool_call['args']}})}\n\n"

                    elif hasattr(last_message, 'content') and last_message.content:
                        if last_message.type == "human":
                            yield f"data: {json.dumps({'type': 'user_message', 'content': last_message.content})}\n\n"
                        else:
                            content_str = str(last_message.content).lower()
                            if ('result 1' in content_str and ('result 2' in content_str or 'result 3' in content_str)) or \
                               ('search result' in content_str and 'result 1' in content_str):
                                continue
                            else:
                                yield f"data: {json.dumps({'type': 'ai_message', 'content': last_message.content})}\n\n"

                yield f"data: {json.dumps({'type': 'complete'})}\n\n"

            except Exception as e:
                yield f"data: {json.dumps({'type': 'error', 'content': str(e)})}\n\n"

        return Response(generate_response(), mimetype='text/event-stream')

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/initialize_local_agent', methods=['POST'])
def initialize_local_agent_route():
    """Initialize the local agent with llama.cpp"""
    init_local_agent()
    return jsonify({'message': 'Local agent initialized'})


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

    # mcp tools if online agent initialized with MCP
    mcp = {'servers': []}
    try:
        if online_agent is not None and hasattr(online_agent, 'mcp_tools_by_server'):
            for server_name, tool_names in online_agent.mcp_tools_by_server.items():
                mcp['servers'].append({'name': server_name, 'tools': [
                                      {'name': n} for n in tool_names]})
    except Exception:
        pass

    return jsonify({'tools': tools_info, 'mcp': mcp})


@app.route('/api/memory', methods=['GET'])
def get_memory_data():
    """Get memory data for display"""
    try:
        memory_path = os.path.join(os.path.dirname(
            os.path.abspath(__file__)), 'memory', 'fact.json')
        with open(memory_path, "r") as f:
            memory = json.load(f)
        return jsonify({'memory': memory})
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
        models_folder = Config.models_folder
        if not os.path.exists(models_folder):
            return jsonify({'models': []})

        models = [f for f in os.listdir(models_folder) if f.endswith('.gguf')]
        return jsonify({'models': models})
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


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'online_agent_initialized': online_agent is not None,
        'local_agent_initialized': local_agent is not None
    })


if __name__ == '__main__':
    print("Starting Flask server...")
    online_agent = asyncio.run(init_online_agent())
    app.run(debug=True, host='0.0.0.0', port=5000, use_reloader=False)
