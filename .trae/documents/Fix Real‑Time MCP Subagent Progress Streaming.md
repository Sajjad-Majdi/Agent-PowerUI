## Backend Findings
- Streaming uses NDJSON over `POST /api/chat` and `/api/chat/local` (`backend/api.py:135–246`, `backend/api.py:249–293`).
- MCP progress is produced in `_run_mcp_agent_session` and queued as `mcp_progress` (`backend/tools.py:64–115`).
- The stream generator drains `progress_queue` first, interleaving progress with main events (`backend/api.py:206–213`).
- Bug source: `_resolve_mcp_progress_channels()` relies on thread‑local `session_id/cancel_event` from the calling thread to locate the session’s `progress_queue` (`backend/tools.py:37–56`, `backend/tools.py:151–161`). The `agent_worker` thread in `/api/chat` does not set these attributes, so MCP tools run without a bound `progress_queue` and emit no real‑time progress. UI only receives the final `tool_message`.

## Fix Plan
1. Propagate session context to the agent thread
   - In `backend/api.py` inside `agent_worker` (before calling `online_agent.send_message(...)`), set thread‑local attributes:
     - `threading.current_thread().session_id = session_id`
     - `threading.current_thread().cancel_event = cancel_event`
   - Add a `finally` block to clean up these attributes after the agent finishes.
2. Keep existing queue wiring
   - Continue creating/storing `mcp_progress_queues[session_id]` and `session_cancel_events[session_id]` as implemented (`backend/api.py:149–153`). This enables `_execute_mcp_agent_tool_in_thread` to reinforce the mapping when it spawns child threads.
3. Optional hardening for streaming
   - Set headers to discourage proxy buffering: add `Cache-Control: no-cache` and `X-Accel-Buffering: no` to the streaming `Response` if needed.
   - Retain interleaving logic and short timeouts to keep the loop responsive.

## Verification
- Add an integration test that triggers an MCP tool and asserts `mcp_progress` events arrive before the terminal `tool_message` (new `backend/tests/test_mcp_realtime_progress.py`).
- Manually run `backend/tests/test_api_streaming.py` to confirm NDJSON is received incrementally and includes `mcp_progress` in real time.
- Exercise the Flutter client: `ApiService.streamChat` should yield `mcp_progress` lines during tool execution; `ChatBloc` already updates `ToolCallState` on `mcp_progress` (`lib/blocs/chat/chat_bloc.dart:137–184`).

## Frontend Note
- Current UI updates `ToolCallBuilder` on `mcp_progress` and shows steps/status live (`lib/components/subunits/tool_call_builder.dart:120–143, 185–243`). No frontend changes required once backend progress streaming is fixed.

If you approve, I will implement the backend thread‑local context propagation, add the test, and verify streaming works end‑to‑end.