# Agent UI (Flutter + Flask)

This is a Windows desktop personal assistant. You can set a Gemini API key in settings and use Gemini models as the brain of the agent, or use any open source model locally and offline for privacy. The agent UI also includes **long-term memory**, useful tools out of the box, and the ability to **add custom MCP subagents** for extended functionality.

_NOTE: you can see the Preview images in **Preview** folder_

## Features

- **Dual agent modes**: cloud Gemini models or local llama.cpp models with a one-click privacy mode toggle.
- **Tooling**: built-in tools (web search, memory, file explorer) plus MCP agents you can add from the UI.
- **Persistent Memory**: long-term memory view, fact deletion, and editable system instructions.
- **Model management**: list/select Gemini models, list/start/stop local models, and monitor local status.
- **Rich message rendering**: Markdown, syntax-highlighted code blocks, math rendering, links, and copy actions.
- **Session history**: sidebar with named sessions, load/delete chat history.
- **Desktop polish**: window sizing, modern Material 3 theme, RTL-aware input, and font support.

## Architecture Overview

- **Frontend**: Flutter app with BLoC for chat state, desktop UI, settings, and tool visualization.
- **Backend**: Flask API that hosts online/local agents, streams responses, and manages memory/sessions.
- **Agents**:
  - Online: Gemini via LangChain + LangGraph.
  - Local: llama.cpp server (llama-server.exe) with OpenAI-compatible HTTP.
- **MCP**: model context protocol adapters for extensible tools defined in `backend/mcp.json`.

## Project Structure (high level)

```
lib/                Flutter UI + state
backend/            Flask API + agents + tools
assets/             Fonts and UI textures
resources/          llama.cpp binaries and local models
```

## Getting Started

### Prerequisites

- Flutter SDK (>= 3.0)
- Python 3.10+ in PATH
- A Gemini API key (set via UI or env)
- Optional: llama.cpp `llama-server.exe` and local GGUF models

### Install backend dependencies

Create a virtual environment and install the Python packages used by the backend:

```
pip install flask flask-cors langchain langgraph langchain-mcp-adapters langchain-openai langchain-tavily requests psutil
```

### Run the app

Option A (recommended): Launch the Flutter app and it will auto-start the backend if Python is available.

```
flutter run -d windows
```

Option B (manual backend):

```
python backend/api.py
```

## Configuration

- **Gemini API key**: configurable in Settings → General, or via `GOOGLE_API_KEY`.
- **Tavily web search**: set `TAVILY_API_KEY` for the web search tool.
- **Local models**: place `.gguf` files in `resources/models/` or set a custom path in Settings.
- **llama.cpp server**: expects `resources/llamacpp/llama-server.exe` or set a custom path in Settings.
- **MCP agents**: edit `backend/mcp.json` or add agents from the Settings UI.

## Backend API (selected endpoints)

- `GET /api/health` – health and agent status
- `POST /api/chat` – online chat streaming
- `POST /api/chat/local` – local chat streaming
- `POST /api/chat/stop` – cancel a streaming session
- `GET /api/list_chat_sessions` – list sessions
- `GET /api/load_session/<id>` – load session
- `DELETE /api/delete_session/<id>` – delete session
- `GET /api/tools` – core tools + MCP agents
- `GET /api/memory` – memory snapshot

## Notes

- Memory, instructions, and API keys are stored under `backend/memory/`.
- SQLite session data lives under `backend/data/`.

## License

Not specified.
