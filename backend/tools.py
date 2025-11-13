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
from mcp_agent import MCPAgent


MCP_TOOL_REGISTRY: Dict[str, Dict[str, Any]] = {}


def _metadata_is_ready(metadata: Optional[Dict[str, Any]]) -> bool:
    if not metadata:
        return False
    required_fields = ['name', 'description', 'system_prompt']
    if metadata.get('status') not in {'ready', 'seed'}:
        return False
    return all(isinstance(metadata.get(field), str) and metadata.get(field).strip() for field in required_fields)


def _resolve_mcp_progress_channels():
    progress_queue = None
    cancel_event = None
    try:
        from api import mcp_progress_queues
        import threading

        session_id = getattr(threading.current_thread(), 'session_id', None)
        if session_id and session_id in mcp_progress_queues:
            progress_queue = mcp_progress_queues[session_id]
        cancel_event = getattr(
            threading.current_thread(), 'cancel_event', None)
    except Exception:
        pass
    return progress_queue, cancel_event


def _run_mcp_agent_session(server_name: str, server_config: Dict[str, Any], system_prompt: str, query: str) -> str:
    async def run():
        if not system_prompt or not system_prompt.strip():
            return json.dumps({'status': 'error', 'result': 'Error: MCP agent system prompt is required but not configured.'})

        agent = MCPAgent(
            mcp_config={server_name: server_config},
            system_prompt=system_prompt,
        )

        tracker = create_mcp_progress_tracker()
        progress_queue, cancel_event = _resolve_mcp_progress_channels()

        try:
            async for response in agent.run_agent(query):
                if cancel_event is not None and cancel_event.is_set():
                    raise asyncio.CancelledError()

                tracker = update_mcp_progress(tracker, response)

                if progress_queue is not None and response.get('type') in {'tool_call', 'tool_message'}:
                    step_event = {
                        'type': 'mcp_progress',
                        'content': {
                            'steps': tracker['steps'],
                            'current_tool': tracker.get('current_tool')
                        }
                    }
                    try:
                        progress_queue.put_nowait(step_event)
                    except Exception:
                        pass
        except asyncio.CancelledError:
            return json.dumps({'status': 'cancelled', 'result': 'Cancelled by user'})

        payload = build_mcp_progress_payload(tracker)
        return json.dumps(payload, ensure_ascii=False)

    try:
        return asyncio.run(run())
    except Exception as exc:
        import traceback
        traceback.print_exc()
        return f"Error: {exc}"


def _execute_mcp_agent_tool(server_name: str, server_config: Dict[str, Any], system_prompt: str, query: str) -> str:
    return _run_mcp_agent_session(server_name, server_config, system_prompt, query)


def build_mcp_agent_toolset() -> List[Tool]:
    MCP_TOOL_REGISTRY.clear()
    toolset: List[Tool] = []
    for entry in Config.list_mcp_agents():
        metadata = entry.get('metadata') if isinstance(entry, dict) else None
        if not _metadata_is_ready(metadata):
            continue

        server_name = entry['name']
        server_config = entry['config']
        display_name = metadata.get('name', server_name).strip()
        description = metadata.get('description', '').strip(
        ) or f"Delegated MCP agent for {server_name}."
        system_prompt = metadata.get('system_prompt', '').strip()

        # Sanitize tool name for LangChain (must be alphanumeric, underscores, dots, colons, dashes)
        tool_name = f"mcp_{server_name}"

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
