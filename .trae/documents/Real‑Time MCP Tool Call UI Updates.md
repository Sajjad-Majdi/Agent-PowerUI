## Problem Confirmation
- Backend streams NDJSON with MCP progress and tool messages correctly.
- Frontend shows a generic “Agent is running…” line with spinners during MCP tool execution and does not show live “Calling <tool>(args)” updates.

## Frontend Fixes
1. Update ToolCallBuilder live status
- File: `lib/components/subunits/tool_call_builder.dart`
- Replace the generic status row for `in_progress` with a dynamic line that renders:
  - Current MCP step name: `currentTool`
  - Current MCP step args: derived from the most recent step with `status == 'in_progress'` in `steps`.
- Remove the extra tiny spinner beside the text; render text-only for clarity.
- Example behavior: shows `Calling Browser Snapshot({ ...args preview... })` and updates continuously as events arrive.

2. Feed current step args from ChatBloc
- File: `lib/blocs/chat/chat_bloc.dart`
- In the `mcp_progress` handler, after extracting `steps`, derive the current in-progress step:
  - `final active = extracted.lastWhere((s) => s.status == 'in_progress', orElse: () => null);`
- Update the corresponding `ToolCallState`:
  - `status: 'in_progress'`
  - `currentTool: content['current_tool']`
  - `toolArgs: active?.args ?? previous.toolArgs` so ToolCallBuilder receives the args of the current step.
- Emit `ChatLoading` immediately after updates to ensure UI re-renders in real time.

3. Remove redundant bottom loading spinner
- File: `lib/blocs/chat/chat_bloc.dart`
- In `tool_message` handling, do not append `ChatMessage(isMe: false, isLoading: true)` when `_pendingToolCallIds.isEmpty`.
- This avoids an unrelated spinner being shown while the agent is running tools; the AI message will replace the card when it arrives.

## Optional Backend Touch (already complete)
- Confirmed per-session progress interleaving and context binding for MCP subagents.
- No further backend changes required for the UI behavior above.

## Verification
- Simulate `mcp_progress` → `tool_call` → `tool_message` event flow and observe Tool Call Builder updating text to `Calling <step>(args)` live, with no extra spinners.
- Use existing streaming tests and manual progress watcher to validate backend; observe frontend updates while running the app.

If approved, I will implement these UI changes and verify they produce real-time step name + args updates in the Tool Call Builder and remove the incorrect spinners.