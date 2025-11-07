- `AsyncCompatibleSqliteSaver` wraps `SqliteSaver` synchronous calls with `asyncio.to_thread`, enabling LangGraph async checkpoints without changing the existing SQLite schema.
- `browse_web` now emits a JSON payload containing MCP step metadata, parsed by `normalize_tool_output` for the Flutter UI to render per-step status.
- `/api/chat/stop` sets a per-session `threading.Event` that both the Gemini stream and MCP tooling poll, while the Flutter bloc cancels its HTTP stream and transitions the input into a stop state driven by `ApiService.cancelChat`.

