- Added `backend/checkpoint.py` providing an async-compatible SQLite saver reused by `online_agent.py` and `local_agent.py`.
- `backend/utils.py` now tracks MCP tool progress, with `tools.py` and `api.py` wiring it into streamed responses consumed by the chat bloc.
- `backend/api.py` introduces per-session cancellation events exposed via `/api/chat/stop`, while `lib/blocs/chat/chat_bloc.dart` and `lib/components/input_bar.dart` consume the flag to swap the send icon into a stop control.

