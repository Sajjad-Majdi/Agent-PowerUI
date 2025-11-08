import asyncio
from flask import Config
from flask.wrappers import json
import requests


def test_config():
    from config import Config
    print("=========== MCP Servers ============")
    print(Config.get_mcp_servers())
    print("=========== List Gemini Models ============")
    print(Config.list_gemini_models())


def test_mcp_agent():
    from mcp_agent import MCPAgent, web_browsing_prompt
    from tools import browse_web
    response = browse_web("how is the weather in Tehran tomorrow?")
    print(response)


def test_online_agent():
    from online_agent import OnlineAgent
    from config import Config
    from tools import browse_web

    agent = OnlineAgent(model="gemini-2.5-flash",
                        tools=[*Config.get_default_tools(), browse_web])

    def generate_response(message, session_id):
        try:
            for last_message in agent.send_message(message, session_id):

                if hasattr(last_message, 'tool_calls') and last_message.tool_calls:
                    for tool_call in last_message.tool_calls:
                        yield json.dumps({'type': 'tool_call', 'content': {'name': tool_call['name'], 'args': tool_call['args']}}) + '\n'

                elif hasattr(last_message, 'content') and last_message.content:
                    if last_message.type == "human":
                        yield json.dumps({'type': 'user_message', 'content': last_message.content}) + '\n'
                    elif last_message.type == "ai":
                        yield json.dumps({'type': 'ai_message', 'content': last_message.content}) + '\n'
                    else:
                        yield json.dumps({'type': 'tool_message', 'content': last_message.content[:100]}) + '\n'

            yield json.dumps({'type': 'complete'}) + '\n'
        except Exception as e:
            yield json.dumps({'type': 'error', 'content': str(e)}) + '\n'

    print("============ Conversation ============")
    for line in generate_response("what tools do you have?!", "test_3fegesf"):
        print(line)
    for line in generate_response("use web browseing tool and search for the weather in Tehran tomorrow", "test_4feesf"):
        print(line)

# ------------- API Tests -------------


def get_session_messages(session_id='session_1'):
    response = requests.get(
        f'http://localhost:5000/api/load_session/{session_id}')
    return response.json()


def list_sessions():
    response = requests.get('http://localhost:5000/api/list_chat_sessions')
    return response.json()


def test_api_chat(message, session_id='session_1343', use_local=False):
    """Send a message to the AI and print streaming responses"""
    endpoint = '/api/chat/local' if use_local else '/api/chat'
    response = requests.post(
        f'http://localhost:5000{endpoint}',
        json={'message': message, 'session_id': session_id},
        stream=True
    )

    for line in response.iter_lines():
        if line:
            data = line.decode('utf-8')
            print(data)


def test_api_local_start(model):
    response = requests.post(
        'http://localhost:5000/api/local/start',
        json={'model': model}
    )
    print(response.json())


if __name__ == '__main__':
    from utils import initialize_local_agent
    from local_agent import LocalAgent

    model = "Qwen3-4B-Instruct-2507-Q4_K_M.gguf"
    agent = LocalAgent(model_name=model)
    agent.start_server()
    # agent.send_message(" hi there")
