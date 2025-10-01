from core.tools import search_web, update_memory
from langgraph.checkpoint.memory import MemorySaver
from langgraph.prebuilt import create_react_agent
from langchain.chat_models import init_chat_model
from langchain_mcp_adapters.tools import load_mcp_tools
from langchain_mcp_adapters.client import MultiServerMCPClient
from flask_cors import CORS
from flask import Flask, request, jsonify, Response
from core.config import Config
from datetime import datetime
import uuid
import asyncio
import json
import sys
import os


app = Flask(__name__)
CORS(app)

# Global agent instance
agent = None
available_tools = []


async def initialize_agent():
    """Initialize the agent with tools"""
    global agent, available_tools

    try:
        # Get MCP servers configuration
        mcp_servers = Config.get_mcp_servers()
        print(f"MCP servers configuration: {mcp_servers}")

        if mcp_servers and len(mcp_servers) > 0:
            try:
                client = MultiServerMCPClient(mcp_servers)
                server_names = list(mcp_servers.keys())
                print(f"Attempting to connect to MCP servers: {server_names}")

                async with client.session(server_names[0]) as session:
                    tools = await load_mcp_tools(session)
                    print(f"Successfully loaded {len(tools)} MCP tools")
                    available_tools = tools + Config.tools

                    # Create agent with all tools
                    llm = init_chat_model(
                        model="google_genai:gemini-2.5-flash")
                    agent = create_react_agent(
                        llm, available_tools, checkpointer=MemorySaver())

                    print(
                        f"✅ Agent initialized with {len(available_tools)} tools")
                    return True
            except Exception as mcp_error:
                print(f"MCP connection failed: {mcp_error}")
                print("Falling back to basic tools only")
        else:
            print("No MCP servers configured, using basic tools only")

        # Fallback to basic tools
        available_tools = Config.tools
        llm = init_chat_model(model="google_genai:gemini-2.5-flash")
        agent = create_react_agent(
            llm, available_tools, checkpointer=MemorySaver())
        print(f"✅ Agent initialized with {len(available_tools)} basic tools")
        return True

    except Exception as e:
        print(f"Error initializing agent: {e}")
        return False


@app.route('/static/<path:filename>')
def serve_static(filename):
    return app.send_static_file(filename)


@app.route('/api/chat', methods=['POST'])
def chat():
    """Handle chat messages"""
    data = request.json
    message = data.get('message', '')
    session_id = data.get('session_id', 'default_session')
    system_prompt = data.get('system_prompt', Config.system_prompt)

    if not message:
        return jsonify({'error': 'Message is required'}), 400

    if not agent:
        return jsonify({'error': 'Agent not initialized'}), 500

    try:
        session_config = {"configurable": {"thread_id": session_id}}

        # Update system prompt if provided
        if system_prompt:
            agent.update_state(values={"messages": [
                {"role": "system", "content": system_prompt}]}, config=session_config)

        def generate_response():
            try:
                for step in agent.stream({"messages": [
                        {"role": "user", "content": message}]}, config=session_config, stream_mode="values"):

                    last_message = step["messages"][-1]

                    # Check if this is a tool call
                    if hasattr(last_message, 'tool_calls') and last_message.tool_calls:
                        for tool_call in last_message.tool_calls:
                            yield f"data: {json.dumps({'type': 'tool_call', 'content': {'name': tool_call['name'], 'args': tool_call['args']}})}\n\n"
                    elif hasattr(last_message, 'content') and last_message.content:
                        # Regular message content
                        if last_message.type == "human":
                            yield f"data: {json.dumps({'type': 'user_message', 'content': last_message.content})}\n\n"
                        else:
                            # Filter out AI messages that contain tool results
                            content_str = str(last_message.content).lower()
                            # Skip messages that are primarily tool results (contain multiple results or search-like content)
                            if ('result 1' in content_str and ('result 2' in content_str or 'result 3' in content_str)) or \
                               ('search result' in content_str and 'result 1' in content_str) or \
                               ('weather in' in content_str and 'forecast' in content_str):
                                # This appears to be a tool result message, skip it
                                continue
                            else:
                                yield f"data: {json.dumps({'type': 'ai_message', 'content': last_message.content})}\n\n"

                # Send completion signal
                yield f"data: {json.dumps({'type': 'complete'})}\n\n"

            except Exception as e:
                yield f"data: {json.dumps({'type': 'error', 'content': str(e)})}\n\n"

        return Response(generate_response(), mimetype='text/event-stream')

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/tools', methods=['GET'])
def get_tools():
    """Get available tools"""
    if not available_tools:
        return jsonify({'tools': []})

    tools_info = []
    for tool in available_tools:
        tools_info.append({
            'name': tool.name,
            'description': tool.description
        })

    return jsonify({'tools': tools_info})


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


@app.route('/api/sessions', methods=['GET'])
def get_sessions():
    """Get chat sessions (placeholder - would need persistent storage)"""
    # This would typically come from a database
    # For now, return empty list
    return jsonify({'sessions': []})


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'agent_initialized': agent is not None})


if __name__ == '__main__':
    print("🚀 Starting Flask server...")
    asyncio.run(initialize_agent())
    app.run(debug=True, host='0.0.0.0', port=5000)
