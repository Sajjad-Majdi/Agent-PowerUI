import os
from functools import partial
from langchain.tools import tool
from langchain_core.tools import Tool
from langchain_tavily import TavilySearch
from datetime import datetime
import json
from typing import Any, Dict, List, Optional
from config import Config
from utils import (
    build_mcp_progress_payload,
    create_mcp_progress_tracker,
    update_mcp_progress,
)
import asyncio
import threading
from mcp_agent import MCPAgent

MCP_TOOL_REGISTRY: Dict[str, Dict[str, Any]] = {}

# Fallback globals
CURRENT_SESSION_ID: Optional[str] = None
CURRENT_PROGRESS_QUEUE = None
CURRENT_CANCEL_EVENT = None


def _resolve_mcp_progress_channels(session_id_arg=None):
    """Resolve progress queue and cancel event."""
    progress_queue = None
    cancel_event = None
    session_id = session_id_arg

    try:
        from api import mcp_progress_queues, session_cancel_events

        # 1. Try to get from thread local storage
        if not session_id:
            session_id = getattr(
                threading.current_thread(), 'session_id', None)

        # 2. Resolve objects using session_id
        if session_id:
            progress_queue = mcp_progress_queues.get(session_id)
            cancel_event = session_cancel_events.get(session_id)

        # 3. Fallbacks
        if not progress_queue and CURRENT_PROGRESS_QUEUE:
            progress_queue = CURRENT_PROGRESS_QUEUE
        if not cancel_event and CURRENT_CANCEL_EVENT:
            cancel_event = CURRENT_CANCEL_EVENT

    except Exception:
        pass

    return progress_queue, cancel_event, session_id


def _run_mcp_agent_session(server_name: str, server_config: Dict[str, Any], system_prompt: str, query: str,
                           progress_queue=None, cancel_event=None, session_id=None) -> str:
    """Async execution logic for the MCP agent."""

    async def run():
        if not system_prompt or not system_prompt.strip():
            return json.dumps({'status': 'error', 'result': 'Error: MCP agent system prompt is required.'})

        # Initialize progress
        if progress_queue is not None:
            try:
                progress_queue.put_nowait({
                    'type': 'mcp_progress',
                    'content': {'status': 'initializing', 'steps': [], 'current_tool': None}
                })
            except Exception:
                pass

        agent = MCPAgent(
            mcp_config={server_name: server_config},
            system_prompt=system_prompt,
        )

        tracker = create_mcp_progress_tracker()

        try:
            async for response in agent.run_agent(query):
                # CRITICAL: Check cancellation inside the loop
                if cancel_event is not None and cancel_event.is_set():
                    raise asyncio.CancelledError("User cancelled operation")

                tracker = update_mcp_progress(tracker, response)

                if progress_queue is not None and response.get('type') in {'tool_call', 'tool_message'}:
                    try:
                        progress_queue.put_nowait({
                            'type': 'mcp_progress',
                            'content': {
                                'status': 'in_progress',
                                'steps': tracker['steps'],
                                'current_tool': tracker.get('current_tool')
                            }
                        })
                    except Exception:
                        pass

        except asyncio.CancelledError:
            # IMMEDIATE STOP SIGNAL
            return json.dumps({'status': 'cancelled', 'result': 'Create NO MORE queries. Task cancelled by user.'})
        except Exception as e:
            tracker['error'] = str(e)
            return json.dumps(build_mcp_progress_payload(tracker), ensure_ascii=False)

        return json.dumps(build_mcp_progress_payload(tracker), ensure_ascii=False)

    try:
        # Create a fresh event loop for this thread
        return asyncio.run(run())
    except Exception as exc:
        return f"Error executing MCP agent: {exc}"


def _execute_mcp_agent_tool(server_name: str, server_config: Dict[str, Any], system_prompt: str, query: str) -> str:
    """
    Entry point for the tool. Spawns a DAEMON thread to allow immediate cancellation.
    """
    # 1. Capture context from the calling thread (Main Agent Thread)
    calling_thread_session_id = getattr(
        threading.current_thread(), 'session_id', None)
    calling_thread_cancel_event = getattr(
        threading.current_thread(), 'cancel_event', None)

    progress_queue, cancel_event, session_id = _resolve_mcp_progress_channels(
        calling_thread_session_id)

    # Fallback for cancel event
    if not cancel_event and calling_thread_cancel_event:
        cancel_event = calling_thread_cancel_event

    # 2. Define wrapper for the new thread
    def target_wrapper():
        # Inject context into the new thread
        ct = threading.current_thread()
        ct.session_id = session_id
        ct.cancel_event = cancel_event

        return _run_mcp_agent_session(
            server_name, server_config, system_prompt, query,
            progress_queue, cancel_event, session_id
        )

    # Container to hold result from the thread
    result_container = {"output": None, "error": None}

    def thread_run():
        try:
            result_container["output"] = target_wrapper()
        except Exception as e:
            result_container["error"] = str(e)

    # 3. CRITICAL FIX: Spawn a DAEMON thread
    # Daemon means if the main app dies, this thread dies instantly.
    t = threading.Thread(target=thread_run, daemon=True)
    t.start()

    # 4. Wait loop with cancellation check
    # We check every 0.2s if the user pressed cancel.
    while t.is_alive():
        t.join(timeout=0.2)
        if cancel_event and cancel_event.is_set():
            # If cancelled, WE RETURN IMMEDIATELY.
            # We do NOT wait for the thread to finish. The thread becomes a "ghost" and dies eventually.
            return json.dumps({'status': 'cancelled', 'result': 'STOP immediately. User cancelled.'})

    if result_container["error"]:
        return f"Error in MCP execution: {result_container['error']}"

    return result_container["output"] or "No output returned."


def build_mcp_agent_toolset() -> List[Tool]:
    MCP_TOOL_REGISTRY.clear()
    toolset: List[Tool] = []
    for entry in Config.list_mcp_agents():
        metadata = entry.get('metadata') if isinstance(entry, dict) else None

        # We removed strict metadata checks to ensure tools load even if metadata is partial
        if not metadata:
            continue

        server_name = entry['name']
        server_config = entry['config']
        display_name = metadata.get('name', server_name).strip()
        description = metadata.get(
            'description', '') or f"Delegated MCP agent for {server_name}."
        system_prompt = metadata.get('system_prompt', '').strip()

        tool_name = f"mcp_{server_name}"

        # Use partial to bake arguments into the function
        runner = partial(_execute_mcp_agent_tool, server_name,
                         server_config, system_prompt)
        runner.__name__ = f"{tool_name}_func"

        tool = Tool(
            name=tool_name,
            description=f"{display_name}: {description}",
            func=runner,
        )

        MCP_TOOL_REGISTRY[tool_name] = {
            'server_name': server_name,
            'metadata': metadata,
            'config': server_config,
            'display_name': display_name,
        }

        toolset.append(tool)

    return toolset


@tool
def think_tool(thought: str) -> str:
    """
    Internal tool to log your thoughts/plans without displaying them to the user. 

    Args:
        thought (str): The thought/plan to log.
    """
    # For now, just return a confirmation message
    return "Thought logged internally."


@tool
def search_web(query: str, num_results: int = 5) -> str:
    """
    search the web for information,

    Note: 
        - use keywords as query, not a full question (example: "capital of France?", "weather in Tokyo?", "latest news on AI")
    Args:
        - query (str): The search query.
        - num_results (int): The number of results to return."""
    search = TavilySearch(
        max_results=num_results,
        api_key=os.environ.get("TAVILY_API_KEY")
    )
    results = search.run(query)
    results = results["results"]

    formated_results = "\n================= Search results ===================\n"
    for i, result in enumerate(results):
        formated_results += f"""---- Result {i + 1} --------------------------------
            *title:* {result['title']}
            *url:* {result['url']}
            *content:* {result['content']}\n"""
    return formated_results


@tool
def update_memory(fact: str, category: str, fact_id: Optional[int] = None) -> str:
    """
    Adds new fact to your memory, or updates an old one
    Only set the fact_id parameter in case the new fact is in conflict with an old one.

    Args:
        fact (str): The fact to update or add to your memory.
        category (str): The category of the fact.
        fact_id (int): The id of the conflicting fact to update.
    """
    # Resolve absolute path and ensure file exists
    memory_path = Config.memory_path
    os.makedirs(os.path.dirname(memory_path), exist_ok=True)
    if not os.path.exists(memory_path):
        # initialize empty memory structure
        with open(memory_path, "w") as f:
            json.dump({}, f)
    with open(memory_path, "r") as f:
        try:
            memory = json.load(f)
        except json.JSONDecodeError:
            memory = {}

    if category not in memory:
        memory[category] = []

    if fact_id is None:
        id = len(memory[category]) + 1

        new_fact = {
            "id": id,
            "fact": fact,
            "timestamp": datetime.now().isoformat()
        }
        memory[category].append(new_fact)
    else:
        for i, item in enumerate(memory[category]):
            if item["id"] == fact_id:
                memory[category][i] = {
                    "id": fact_id,
                    "fact": fact,
                    "timestamp": datetime.now().isoformat()
                }
                break

    # Save back to file
    with open(memory_path, "w") as f:
        json.dump(memory, f, indent=4)

    return "memory updated successfully"


@tool
def file_explorer_tool(action: str, arg1: str = "", arg2: str = "") -> str:
    """
    Tool for interacting with local file system - navigate, list, rename, move, copy, delete files and folders.

    Note:
        - If no path is provided with "list" action, available drives will be shown on Windows systems.
        - Use drive letters to navigate (e.g., "C:\\", "D:\\").
        - Always call "list" first to see available drives before navigating.
        - Avoid modifying system-critical directories (e.g., C:\\Windows, C:\\Program Files and everything inside drive C).
        - Use search action to search for files and folders by name (e.g., "action: search, arg1: MyMovies").
    Args:
        action: Operation to perform (list, rename, move, copy, delete, create_folder, search, tree)
        arg1: Primary argument (path for most operations, query for search)
        arg2: Secondary argument (new_name for rename, destination for move/copy)
    """
    import os
    import shutil
    import json
    from pathlib import Path
    try:
        if action == "list":
            # If no path provided, show available drives on Windows
            if not arg1:
                if os.name == 'nt':  # Windows
                    try:
                        import subprocess
                        result = subprocess.run(
                            ['powershell', '-Command',
                                'Get-PSDrive -PSProvider FileSystem | Select-Object Name, Root, @{Name="Used(GB)";Expression={[math]::Round($_.Used/1GB,2)}}, @{Name="Free(GB)";Expression={[math]::Round($_.Free/1GB,2)}} | Format-Table -AutoSize'],
                            capture_output=True,
                            text=True,
                            timeout=5
                        )
                        if result.returncode == 0:
                            return f"Available drives:\n\n{result.stdout}\n\nUse 'list' with a drive path (e.g., 'C:\\') to explore contents."
                    except Exception as e:
                        pass
                # Fallback to current directory if not Windows or command fails
                target = Path.cwd()
            else:
                target = Path(arg1)

            if not target.exists():
                return f"Error: Path does not exist: {arg1}"

            items = []
            for item in target.iterdir():
                item_type = "folder" if item.is_dir() else "file"
                size_info = f" ({item.stat().st_size} bytes)" if item.is_file(
                ) else ""
                size_mb = f" ({item.stat().st_size / (1024 * 1024):.2f} MB)" if item.is_file() else ""
                items.append(f"  - {item.name} [{item_type}]{size_mb}")

            result = f"Current path: {target.absolute()}\n\nContents:\n" + \
                "\n".join(items)
            return result

        elif action == "rename":
            source = Path(arg1)
            if not source.exists():
                return f"Error: Path does not exist: {arg1}"
            target = source.parent / arg2
            source.rename(target)
            return f"Success: Renamed to {target.absolute()}"

        elif action == "move":
            source = Path(arg1)
            dest = Path(arg2)
            if not source.exists():
                return f"Error: Source does not exist: {arg1}"
            shutil.move(str(source), str(dest))
            return f"Success: Moved to {dest}"

        elif action == "copy":
            source = Path(arg1)
            dest = Path(arg2)
            if not source.exists():
                return f"Error: Source does not exist: {arg1}"
            if source.is_dir():
                shutil.copytree(str(source), str(dest))
            else:
                shutil.copy2(str(source), str(dest))
            return f"Success: Copied to {dest}"

        elif action == "delete":
            target = Path(arg1)
            if not target.exists():
                return f"Error: Path does not exist: {arg1}"
            if target.is_dir():
                shutil.rmtree(str(target))
            else:
                target.unlink()
            return f"Success: Deleted {target.absolute()}"

        elif action == "create_folder":
            target = Path(arg1)
            target.mkdir(parents=True, exist_ok=True)
            return f"Success: Created folder at {target.absolute()}"

        elif action == "search":
            search_query = arg1
            results = []

            # Search all drives on Windows except C:, or root on Unix-like systems
            if os.name == 'nt':  # Windows
                import subprocess
                try:
                    # Get all available drives
                    drive_result = subprocess.run(
                        ['powershell', '-Command',
                            'Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root'],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )
                    drives = [d.strip() for d in drive_result.stdout.strip().split(
                        '\n') if d.strip() and not d.strip().upper().startswith('C:')]
                except Exception:
                    drives = [f"{chr(d)}:\\" for d in range(
                        65, 91) if d != 67 and Path(f"{chr(d)}:\\").exists()]

                for drive in drives:
                    try:
                        drive_path = Path(drive)
                        if drive_path.exists():
                            for item in drive_path.rglob(f"*{search_query}*"):
                                item_type = "folder" if item.is_dir() else "file"
                                results.append(
                                    f"  - {item.name} [{item_type}] at {item.absolute()}")
                    except (PermissionError, OSError):
                        continue
            else:
                # Unix-like systems: search from root
                try:
                    root = Path('/')
                    for item in root.rglob(f"*{search_query}*"):
                        item_type = "folder" if item.is_dir() else "file"
                        results.append(
                            f"  - {item.name} [{item_type}] at {item.absolute()}")
                except (PermissionError, OSError):
                    pass

            if not results:
                return f"Search query '{search_query}' found no results in the system"

            return f"Search query '{search_query}' found {len(results)} result(s):\n" + "\n".join(results)

        elif action == "tree":
            target = Path(arg1) if arg1 else Path.cwd()
            if not target.exists():
                return f"Error: Path does not exist: {arg1}"

            def build_tree(directory: Path, max_depth: int = 3, current_depth: int = 0, prefix: str = ""):
                if current_depth >= max_depth:
                    return []

                lines = []
                try:
                    items = sorted(directory.iterdir())
                    for i, item in enumerate(items):
                        is_last = i == len(items) - 1
                        connector = "└── " if is_last else "├── "
                        item_type = "[folder]" if item.is_dir() else "[file]"
                        lines.append(
                            f"{prefix}{connector}{item.name} {item_type}")

                        if item.is_dir():
                            extension = "    " if is_last else "│   "
                            subtree = build_tree(
                                item, max_depth, current_depth + 1, prefix + extension)
                            lines.extend(subtree)
                except PermissionError:
                    lines.append(f"{prefix}[Permission denied]")

                return lines

            tree_lines = [f"Tree structure of {target.absolute()}:"]
            tree_lines.extend(build_tree(target))
            return "\n".join(tree_lines)

        else:
            return f"Error: Unknown action: {action}"

    except Exception as e:
        return f"Error: {str(e)}"


if __name__ == "__main__":
    # Test 1: List current directory
    # print("Test 1: List current directory")
    # res = file_explorer_tool("list")
    # print(res)
    # print("=====================================")

    # Test 2: Search for Python files
    # print("Test 2: Search for .py files")
    # res = file_explorer_tool("search", "MyMovies")
    # print(res)
    # print("=====================================")

    # Test 3: Tree structure
    # print("Test 3: Tree structure")
    # res = file_explorer_tool("tree", "D:/")
    # print(res)
    # print("=====================================")

    # Test 4: Invalid action
    print("Test 4: Invalid action")
    res = file_explorer_tool("invalid_action")
    print(res)
    print("=====================================")

    # Test 5: Non-existent path
    print("Test 5: Non-existent path")
    res = file_explorer_tool("list", "/nonexistent/path")
    print(res)
