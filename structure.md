- Added `backend/checkpoint.py` providing an async-compatible SQLite saver reused by `online_agent.py` and `local_agent.py`.
- `backend/utils.py` now tracks MCP tool progress, with `tools.py` and `api.py` wiring it into streamed responses consumed by the chat bloc.
- `backend/api.py` introduces per-session cancellation events exposed via `/api/chat/stop`, while `lib/blocs/chat/chat_bloc.dart` and `lib/components/input_bar.dart` consume the flag to swap the send icon into a stop control.
- Local model management moved into `backend/utils.py` with helpers for listing GGUF sizes and starting/stopping llama.cpp; `backend/api.py` exposes `/api/local/start|stop|status` and enhanced `/api/list_models`.
- `lib/services/api_service.dart` wraps the new payload via `LocalModelsResult`, drives start/stop/status helpers, and propagates local-mode flags to `ChatBloc`.
- `lib/components/app_bar.dart` now hosts the privacy mode toggle, local model picker, and terminate button, while `lib/pages/chat_interface.dart` orchestrates theme swapping and llama server lifecycle.

