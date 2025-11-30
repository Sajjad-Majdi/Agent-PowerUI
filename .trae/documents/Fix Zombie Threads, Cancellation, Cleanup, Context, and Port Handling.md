## Overview
- Replace global thread pool with per‑request daemon threads for MCP tool execution.
- Stop infinite retries by returning an explicit cancellation completion to the LLM.
- Ensure backend exits cleanly via an atexit cleanup that cancels sessions and stops local agent.
- Pass `session_id` and `cancel_event` through the execution path explicitly.
- Make local agent choose a free port when 8080 is unavailable.

## backend/tools.py Refactor
1. Remove global `ThreadPoolExecutor` defined at `backend/tools.py:29-31`.
2. Update `_run_mcp_agent_session` (`backend/tools.py:80-149`):
   - Keep explicit parameters `progress_queue`, `cancel_event`, `session_id` and prefer them over resolver.
   - Catch `asyncio.CancelledError` and return the final string: `"Create NO MORE queries. Task cancelled by user."` (do not re‑raise).
3. Rewrite `_execute_mcp_agent_tool` (`backend/tools.py:181-204`) to the pattern:
   - Resolve `progress_queue`, `cancel_event`, `session_id` via `_resolve_mcp_progress_channels` (`backend/tools.py:42-78`).
   - Define `target_wrapper()` that sets thread context, calls `_run_mcp_agent_session(...)` passing `progress_queue`, `cancel_event`, `session_id`, and stores the result into a thread‑safe container.
   - Start `threading.Thread(target=target_wrapper, daemon=True)`.
   - Wait loop: `t.join(timeout=0.2)` and if `cancel_event.is_set()`, return `json.dumps({'status': 'cancelled', 'result': 'STOP immediately. User cancelled.'})` immediately.
   - On completion, return the result from the wrapper.
4. Keep `_resolve_mcp_progress_channels` but ensure explicit values are passed to `_run_mcp_agent_session`; use resolver only as fallback.
5. Ensure all newly created threads are `daemon=True` to avoid process hang on exit.

## backend/api.py Updates
1. Add a process cleanup via `atexit` near globals (`~backend/api.py:94-104 area` or before `__main__`):
   - `def cleanup_on_exit():`
     - Iterate all `session_cancel_events` and call `.set()` on each.
     - Call `stop_local_agent_util()` to shut down local agent.
   - `import atexit` and `atexit.register(cleanup_on_exit)`.
2. Keep session context propagation:
   - In `chat()` (`backend/api.py:135-276`), continue setting `CURRENT_SESSION_ID`, `CURRENT_PROGRESS_QUEUE`, `CURRENT_CANCEL_EVENT` in `tools` module.
   - Agent worker threads already set `session_id` and `cancel_event` on the current thread (`backend/api.py:166-177`), which complements explicit argument passing in tools.
3. No change to routes’ streaming semantics; cancellation still drains progress queue and yields `{'type':'cancelled'}` once.

## backend/local_agent.py Port Handling
1. Add a helper `_find_available_port(preferred: int = 8080) -> int` using `socket`:
   - Try binding to `preferred`; if unavailable, bind to port `0` to let OS select a free port; return the chosen port.
2. Modify initialization/start to use dynamic port:
   - On `start_server()` (`backend/local_agent.py:37-115`), before launching, set `self._port = self._find_available_port(8080)` unless an existing llama server is detected on 8080 via `_check_port_active()` (in that case, attach).
   - Replace current pre‑spawn busy‑port wait logic with the availability check; remove raises that assume only llama is on 8080.
3. Ensure `self.llm` base URL uses the selected `self._port` everywhere (`backend/local_agent.py:49-55`, `108-114`).

## Context Passing and Cancellation Semantics
- Explicitly pass `progress_queue`, `cancel_event`, `session_id` from `_execute_mcp_agent_tool` into `_run_mcp_agent_session` rather than relying solely on thread‑locals.
- In `_run_mcp_agent_session`, when `cancel_event.is_set()` during streaming, raise `asyncio.CancelledError` and catch it to return the final stop string to prevent agent retries.
- The wait loop in `_execute_mcp_agent_tool` checks `cancel_event.is_set()` and returns a cancellation JSON immediately to avoid hanging threads.

## Testing and Verification
- Unit: run existing tests under `backend/tests/` (e.g., streaming, local restart, utils) and add a focused test for cancellation completing without retries.
- Manual:
  - Start backend, trigger an MCP tool call, then cancel; verify:
    - The UI receives progress then a single cancellation event.
    - No further tool calls are emitted and no zombie threads accumulate.
  - Close the frontend; confirm the backend exits (daemon threads + atexit cleanup).
  - Start local agent when 8080 is occupied; confirm server binds to a new port and agent connects.

## Compatibility Notes
- Keep LangChain `Tool` creation intact; the runner remains `partial(_execute_mcp_agent_tool, ...)` so frontend contracts do not change.
- Maintain JSON payload structure for progress and final results; only adjust the cancellation messages per requirements.
- No changes to public API routes beyond adding cleanup registration.

## Risks Mitigated
- Deadlocks from a saturated thread pool eliminated by per‑request daemon threads.
- Infinite retry loops stopped via explicit final cancellation message.
- Orphan processes prevented by daemon threads and an atexit cleanup.
- UI progress context preserved by explicit propagation of `session_id` and `cancel_event`.
- Port conflicts avoided by dynamic selection when 8080 is busy.