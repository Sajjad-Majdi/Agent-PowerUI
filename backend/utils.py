import json
import os
import sqlite3
from typing import Any, Dict, List, Optional

from config import Config
from online_agent import OnlineAgent
from local_agent import LocalAgent


def _list_session_ids():
    """Internal: list unique thread_ids from LangGraph checkpoints table, ordered by most recent first."""
    db_path = Config.db_path
    with sqlite3.connect(db_path, check_same_thread=False) as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT thread_id FROM checkpoints GROUP BY thread_id ORDER BY MAX(checkpoint_id) DESC")
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

                # Skip system messages and tool messages
                if msg_type == 'system' or msg_type == 'tool':
                    continue

                # Check if this AI message has tool calls
                if msg_type == 'ai' and hasattr(msg, 'tool_calls') and msg.tool_calls:
                    # Include tool calls in the content
                    formatted_messages.append({
                        'type': msg_type,
                        'content': str(content),
                        'is_user': False,
                        'tool_calls': msg.tool_calls
                    })
                else:
                    formatted_messages.append({
                        'type': msg_type,
                        'content': str(content),
                        'is_user': msg_type == 'human'
                    })

        return formatted_messages
    except Exception:
        return []


def get_memory():
    with open(Config.memory_path, "r") as f:
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
        available_tools = Config.get_default_tools()
        online_agent = OnlineAgent(
            model=Config.DEFAULT_GEMINI_MODEL, tools=available_tools)

        return online_agent
    except Exception as e:
        print(f"Error initializing online agent: {e}")
        return None


local_agent: Optional[LocalAgent] = None
local_model_name: Optional[str] = None


def list_local_models() -> List[Dict[str, Any]]:
    """Return available GGUF models with file sizes."""
    models: List[Dict[str, Any]] = []
    folder = Config.models_folder
    if not os.path.exists(folder):
        return models

    for entry in os.listdir(folder):
        if not entry.lower().endswith(".gguf"):
            continue
        file_path = os.path.join(folder, entry)
        try:
            size_bytes = os.path.getsize(file_path)
        except OSError:
            size_bytes = 0
        models.append({"name": entry, "size_bytes": size_bytes})

    models.sort(key=lambda m: m["name"])
    return models


def _resolve_model_name(preferred: Optional[str] = None) -> str:
    """Return a valid model name, preferring the provided option."""
    models = list_local_models()
    names = [m["name"] for m in models]
    if preferred and preferred in names:
        return preferred
    if preferred and preferred not in names:
        raise ValueError(f"Model '{preferred}' not found in local models")
    if not names:
        raise ValueError("No local models available")
    return names[0]


def initialize_local_agent(model_name: Optional[str] = None) -> LocalAgent:
    """Initialize (or restart) the local agent with the requested model."""
    global local_agent, local_model_name

    selected_model = _resolve_model_name(model_name)

    if local_agent and local_agent.is_running():
        if local_model_name == selected_model:
            return local_agent
        stop_local_agent()

    agent = LocalAgent(model_name=selected_model, context_window=8192)
    agent.start_server()
    agent.initialize_agent(Config.get_default_tools())

    local_agent = agent
    local_model_name = selected_model
    return agent


def stop_local_agent():
    """Terminate the running local agent if present."""
    global local_agent, local_model_name
    if local_agent:
        try:
            local_agent.stop_server()
        except Exception as exc:
            print(f"Error stopping local agent: {exc}")
    local_agent = None
    local_model_name = None


def get_local_agent() -> LocalAgent:
    """Return the current LocalAgent instance if running."""
    return local_agent


def get_local_agent_status() -> Dict[str, Any]:
    """Return running status information for the local agent."""
    running = local_agent.is_running() if local_agent else False
    return {
        "running": running,
        "model": local_model_name if running else None,
    }


def create_mcp_progress_tracker() -> Dict[str, Any]:
    """Return a fresh state container for MCP progress tracking."""
    return {
        "steps": [],
        "step_lookup": {},
        "current_tool": None,
        "final_result": None,
        "error": None,
        "last_message": None,
    }


def update_mcp_progress(tracker: Optional[Dict[str, Any]], event: Dict[str, Any]) -> Dict[str, Any]:
    """Consume a single MCP agent event and update the progress tracker."""
    if tracker is None:
        tracker = create_mcp_progress_tracker()

    if not event:
        return tracker

    event_type = event.get("type")
    content = event.get("content")

    if event_type == "tool_call":
        calls = content if isinstance(content, list) else [content]
        if calls is None:
            return tracker

        for call in calls:
            if not isinstance(call, dict):
                continue
            step_id = call.get("id") or f"step_{len(tracker['steps']) + 1}"
            step = {
                "id": step_id,
                "name": call.get("name") or "tool",
                "status": "in_progress",
                "args": call.get("args", {}),
                "outputs": [],
            }
            tracker["step_lookup"][step_id] = step
            tracker["steps"].append(step)
            tracker["current_tool"] = step["name"]

    elif event_type == "tool_message":
        if isinstance(content, dict):
            step_id = content.get("tool_call_id")
            message_text = content.get("message")
            if step_id and step_id in tracker["step_lookup"]:
                step = tracker["step_lookup"][step_id]
                step["status"] = "completed"
                if message_text:
                    trimmed = message_text.strip()
                    if len(trimmed) > 800:
                        trimmed = trimmed[:800] + "..."
                    step.setdefault("outputs", []).append(trimmed)
                    tracker["last_message"] = trimmed
                tracker["current_tool"] = None
            elif message_text:
                tracker["last_message"] = message_text

    elif event_type == "ai":
        tracker["final_result"] = content

    elif event_type == "error":
        tracker["error"] = content
        tracker["current_tool"] = None

    return tracker


def build_mcp_progress_payload(tracker: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    """Serialize tracker state into a JSON-friendly payload."""
    tracker = tracker or create_mcp_progress_tracker()
    steps_payload: List[Dict[str, Any]] = []
    for step in tracker["steps"]:
        steps_payload.append({
            "id": step.get("id"),
            "name": step.get("name"),
            "status": step.get("status"),
            "args": step.get("args", {}),
            "outputs": step.get("outputs", []),
        })

    payload: Dict[str, Any] = {
        "result": tracker.get("final_result") or tracker.get("last_message") or "",
        "mcp_progress": {
            "current_tool": tracker.get("current_tool"),
            "steps": steps_payload,
        },
    }

    if tracker.get("error"):
        payload["error"] = tracker["error"]

    return payload


def normalize_tool_output(content: Any) -> Dict[str, Any]:
    """Convert arbitrary tool output into a normalized dict for streaming."""
    parsed: Dict[str, Any]

    if isinstance(content, dict):
        parsed = content
    elif isinstance(content, str):
        stripped = content.strip()
        try:
            parsed = json.loads(stripped)
            if not isinstance(parsed, dict):
                parsed = {"text": stripped}
        except json.JSONDecodeError:
            parsed = {"text": stripped}
    else:
        parsed = {"text": str(content)}

    normalized: Dict[str, Any] = {
        "text": parsed.get("result")
        or parsed.get("text")
        or parsed.get("message")
        or "",
    }

    progress = parsed.get("mcp_progress")
    if isinstance(progress, dict):
        normalized["progress_kind"] = "mcp"
        normalized["current_tool"] = progress.get("current_tool")
        normalized["steps"] = progress.get("steps", [])

    if parsed.get("error"):
        normalized["error"] = parsed["error"]

    normalized["raw"] = parsed

    return normalized


if __name__ == "__main__":
    # print(_list_session_ids())
    print(Config.memory_path)
