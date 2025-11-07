- Added `backend/checkpoint.py` providing an async-compatible SQLite saver reused by `online_agent.py` and `local_agent.py`.
- `backend/utils.py` now tracks MCP tool progress, with `tools.py` and `api.py` wiring it into streamed responses consumed by the chat bloc.

