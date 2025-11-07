- `AsyncCompatibleSqliteSaver` wraps `SqliteSaver` synchronous calls with `asyncio.to_thread`, enabling LangGraph async checkpoints without changing the existing SQLite schema.
- `browse_web` now emits a JSON payload containing MCP step metadata, parsed by `normalize_tool_output` for the Flutter UI to render per-step status.

