import json
import os
import sqlite3

# Handle both direct execution and module import
if __name__ == "__main__":
    # Direct execution - use absolute imports
    import sys
    sys.path.insert(0, os.path.dirname(
        os.path.dirname(os.path.abspath(__file__))))
    from core.config import Config
    from core.online_agent import OnlineAgent
    from core.local_agent import LocalAgent

else:
    # Module import - use relative imports
    from .config import Config
    from .online_agent import OnlineAgent
    from .local_agent import LocalAgent


def _list_session_ids():
    """Internal: list unique thread_ids from LangGraph checkpoints table."""
    db_path = Config.db_path
    with sqlite3.connect(db_path, check_same_thread=False) as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT DISTINCT thread_id FROM checkpoints ORDER BY thread_id")
        sessions = cursor.fetchall()
        return [session[0] for session in sessions]


def get_session_first_user_message(session_id: str, agent_instance=None):
    """Return the first user (human) message content for a session if available.

    Falls back to None if the session has no user messages or cannot be loaded.
    """
    # If no agent instance is provided, skip heavy loading and fall back.
    if agent_instance is None:
        return None
    try:
        messages = get_session_messages(session_id, agent_instance)
        for msg in messages:
            if msg.get('is_user') and isinstance(msg.get('content'), str):
                text = msg['content'].strip()
                if text:
                    return text
        return None
    except Exception:
        return None


def list_chat_sessions_named(agent_instance=None):
    """List chat sessions with a human-friendly name derived from first user message."""
    sessions = _list_session_ids()
    result = []
    for sid in sessions:
        name = get_session_first_user_message(sid, agent_instance)
        result.append({'id': sid, 'name': name if name else sid})
    return result


def delete_session(session_id: str) -> bool:
    """Delete a specific chat session from the LangGraph checkpoints table.

    Returns True when at least one row is deleted, False otherwise.
    """
    db_path = Config.db_path
    try:
        with sqlite3.connect(db_path, check_same_thread=False) as conn:
            cursor = conn.cursor()
            cursor.execute(
                "DELETE FROM checkpoints WHERE thread_id = ?", (session_id,))
            rows_affected = cursor.rowcount
            conn.commit()
            if rows_affected > 0:
                print(f"session '{session_id}' deleted successfully")
                return True
            else:
                print(f"session '{session_id}' not found")
                return False
    except Exception as e:
        print(f"couldn't delete session '{session_id}': {e}")
        return False


def get_session_messages(session_id, agent_instance=None):
    """Get all messages for a specific chat session from the LangGraph checkpoints table."""

    # Use provided agent or create a new one
    if agent_instance is None:
        agent = OnlineAgent(model="gemini-2.5-flash",
                            tools=Config.get_default_tools())
        agent.initialize_agent()
        graph_agent = agent.agent
    else:
        graph_agent = agent_instance.agent if hasattr(
            agent_instance, 'agent') else agent_instance

    try:
        state = graph_agent.get_state(
            config={"configurable": {"thread_id": session_id}})

        # Extract messages from StateSnapshot
        formatted_messages = []
        if hasattr(state, 'values') and 'messages' in state.values:
            for msg in state.values['messages']:
                msg_type = msg.type if hasattr(msg, 'type') else 'unknown'
                content = msg.content if hasattr(msg, 'content') else ''

                # Skip system messages, tool messages, and empty content
                if msg_type == 'system':
                    continue

                formatted_messages.append({
                    'type': msg_type,
                    'content': str(content),
                    'is_user': msg_type == 'human'
                })

        return formatted_messages
    except Exception:
        return []


def get_memory():
    memory_path = os.path.join(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))), 'memory', 'fact.json')
    with open(memory_path, "r") as f:
        memory = json.load(f)

    text = ""
    for category in memory:
        text += f"Category: {category}\n"
        for fact in memory[category]:
            text += f"  - Fact {fact['id']}: {fact['fact']}\n"
            text += f"  - Last updated: {fact['timestamp']}\n"
        text += "\n"

    return text


async def initialize_online_agent():
    """Initialize the online agent with Gemini"""
    global online_agent, available_tools

    try:
        mcp_servers = Config.get_mcp_servers()
        tools = Config.get_default_tools()
        online_agent = OnlineAgent(
            model=Config.DEFAULT_GEMINI_MODEL, tools=tools)

        if mcp_servers and len(mcp_servers) > 0:
            await online_agent.initialize_agent_with_mcp(mcp_servers)
        else:
            online_agent.initialize_agent()

        available_tools = tools
        return online_agent
    except Exception:
        return None


def initialize_local_agent():
    """Initialize the local agent with llama.cpp"""
    global local_agent

    try:
        model_name = "Qwen3-4B-Instruct-2507-Q4_K_M.gguf"
        local_agent = LocalAgent(model_name=model_name, context_window=8192)
        local_agent.start_server()
        local_agent.initialize_agent(Config.get_default_tools())
        return True
    except Exception:
        return False


if __name__ == "__main__":
    print(_list_session_ids())
