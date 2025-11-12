import json
import os
from datetime import datetime
from typing import Literal

backend_directory = os.path.dirname(__file__)
project_root = os.path.dirname(backend_directory)


class Config:

    # Available online Gemini models and default selection
    GEMINI_MODELS = [
        "gemini-2.5-flash-lite",
        "gemini-2.5-flash",
        "gemini-2.5-pro",
    ]
    DEFAULT_GEMINI_MODEL: Literal["gemini-2.5-flash-lite",
                                  "gemini-2.5-flash", "gemini-2.5-pro"] = "gemini-2.5-flash"

    DEFAULT_MODELS_FOLDER = os.path.join(project_root, 'resources', 'models')
    DEFAULT_LLAMA_SERVER_PATH = os.path.join(
        project_root, 'resources', 'llamacpp', 'llama-server.exe')
    db_path = os.path.join(backend_directory, 'data', 'chat_storage.db')

    memory_path = os.path.join(backend_directory, 'memory', 'fact.json')
    mcp_state_path = os.path.join(
        backend_directory, 'memory', 'mcp_state.json')
    instructions_path = os.path.join(
        backend_directory, 'memory', 'instructions.json')
    api_key_path = os.path.join(
        backend_directory, 'memory', 'api_key.json')
    paths_config_path = os.path.join(
        backend_directory, 'memory', 'paths.json')

    @staticmethod
    def _load_path_overrides() -> dict:
        try:
            if os.path.exists(Config.paths_config_path):
                with open(Config.paths_config_path, 'r') as handle:
                    data = json.load(handle)
                    if isinstance(data, dict):
                        return data
        except Exception as exc:
            print(f"Error loading path overrides: {exc}")
        return {}

    @staticmethod
    def _save_path_overrides(data: dict):
        try:
            os.makedirs(os.path.dirname(
                Config.paths_config_path), exist_ok=True)
            with open(Config.paths_config_path, 'w') as handle:
                json.dump(data, handle, indent=2)
        except Exception as exc:
            print(f"Error saving path overrides: {exc}")

    @staticmethod
    def get_models_folder() -> str:
        overrides = Config._load_path_overrides()
        folder = overrides.get('models_folder') or Config.DEFAULT_MODELS_FOLDER
        folder = os.path.abspath(os.path.expanduser(folder))
        try:
            os.makedirs(folder, exist_ok=True)
        except Exception as exc:
            print(f"Warning: could not ensure models folder exists: {exc}")
        return folder

    @staticmethod
    def set_models_folder(path: str):
        overrides = Config._load_path_overrides()
        normalized = path.strip() if isinstance(path, str) else ''
        if normalized:
            overrides['models_folder'] = os.path.abspath(
                os.path.expanduser(normalized))
        else:
            overrides.pop('models_folder', None)
        Config._save_path_overrides(overrides)

    @staticmethod
    def get_llama_server_path() -> str:
        overrides = Config._load_path_overrides()
        path = overrides.get(
            'llama_server_path') or Config.DEFAULT_LLAMA_SERVER_PATH
        return os.path.abspath(os.path.expanduser(path))

    @staticmethod
    def set_llama_server_path(path: str):
        overrides = Config._load_path_overrides()
        normalized = path.strip() if isinstance(path, str) else ''
        if normalized:
            overrides['llama_server_path'] = os.path.abspath(
                os.path.expanduser(normalized))
        else:
            overrides.pop('llama_server_path', None)
        Config._save_path_overrides(overrides)

    @staticmethod
    def get_path_config() -> dict:
        overrides = Config._load_path_overrides()
        return {
            'models_folder': Config.get_models_folder(),
            'llama_server_path': Config.get_llama_server_path(),
            'defaults': {
                'models_folder': Config.DEFAULT_MODELS_FOLDER,
                'llama_server_path': Config.DEFAULT_LLAMA_SERVER_PATH,
            },
            'overrides': {
                'models_folder': bool(overrides.get('models_folder')),
                'llama_server_path': bool(overrides.get('llama_server_path')),
            }
        }

    @staticmethod
    def get_mcp_state():
        """Get the current state of MCP tools (enabled/disabled per server)"""
        try:
            if not os.path.exists(Config.mcp_state_path):
                # Create default state with all tools enabled
                mcp_servers = Config.get_mcp_servers()
                default_state = {server: True for server in mcp_servers.keys()}
                Config.set_mcp_state(default_state)
                return default_state

            with open(Config.mcp_state_path, 'r') as f:
                return json.load(f)
        except Exception:
            return {}

    @staticmethod
    def set_mcp_state(state: dict):
        """Set the state of MCP tools (enabled/disabled per server)"""
        try:
            os.makedirs(os.path.dirname(Config.mcp_state_path), exist_ok=True)
            with open(Config.mcp_state_path, 'w') as f:
                json.dump(state, f, indent=2)
        except Exception as e:
            print(f"Error saving MCP state: {e}")

    @staticmethod
    def get_enabled_mcp_servers():
        """Get only the MCP servers that are currently enabled"""
        all_servers = Config.get_mcp_servers()
        state = Config.get_mcp_state()
        return {name: config for name, config in all_servers.items() if state.get(name, True)}

    @staticmethod
    def get_instructions():
        """Get saved agent instructions"""
        try:
            if not os.path.exists(Config.instructions_path):
                return ""
            with open(Config.instructions_path, 'r') as f:
                data = json.load(f)
                return data.get('instructions', '')
        except Exception as e:
            print(f"Error loading instructions: {e}")
            return ""

    @staticmethod
    def set_instructions(instructions: str):
        """Save agent instructions"""
        try:
            os.makedirs(os.path.dirname(
                Config.instructions_path), exist_ok=True)
            with open(Config.instructions_path, 'w', encoding='utf-8') as f:
                json.dump({'instructions': instructions},
                          f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"Error saving instructions: {e}")

    @staticmethod
    def get_gemini_api_key():
        """Get saved Gemini API key or fall back to environment variable"""
        try:
            if os.path.exists(Config.api_key_path):
                with open(Config.api_key_path, 'r') as f:
                    data = json.load(f)
                    key = data.get('api_key', '').strip()
                    if key:
                        return key
        except Exception as e:
            print(f"Error loading API key: {e}")

        # Fall back to environment variable
        return os.environ.get('GOOGLE_API_KEY', '')

    @staticmethod
    def set_gemini_api_key(api_key: str):
        """Save Gemini API key"""
        try:
            os.makedirs(os.path.dirname(Config.api_key_path), exist_ok=True)
            with open(Config.api_key_path, 'w') as f:
                json.dump({'api_key': api_key.strip()}, f, indent=2)
        except Exception as e:
            print(f"Error saving API key: {e}")

    @staticmethod
    def get_system_prompt():
        from utils import get_memory
        instructions = Config.get_instructions()
        instructions_block = f"\n\nUSER INSTRUCTIONS:\n{instructions}\n" if instructions else ""

        return f"""You are a continuously evolving personal assistant with persistent memory. You learn from every interaction to become increasingly helpful over time.

                    CORE IDENTITY:
                    - Conversational and approachable, yet concise and efficient
                    - Proactive in anticipating needs based on learned patterns
                    - Transparent about what you know, remember, and can do

                    MEMORY INTELLIGENCE:
                    You maintain structured long-term memory to function like a real human assistant:
                    - Extract and store key facts: user preferences, habits, context, relationships, goals
                    - Build procedural knowledge: successful workflows, effective strategies, problem-solving patterns
                    - Learn from mistakes: record failures and their causes to avoid repetition
                    - Track temporal context: dates, deadlines, reminders (today is {datetime.now().strftime("%Y-%m-%d")})
                    - Create connections: link related information across conversations

                    Current Memory:
                    <memory>
                    {get_memory()}
                    </memory>

                    ADAPTIVE BEHAVIOR:
                    - Use stored knowledge to personalize every response
                    - Reference past interactions naturally when relevant
                    - Suggest improvements based on learned patterns
                    - Ask clarifying questions to deepen understanding
                    - Adjust your approach based on user feedback

                    INTERACTION STYLE:
                    - Be natural and conversational, not robotic
                    - Keep responses focused and to-the-point
                    - Explain your reasoning when using remembered information
                    - Show initiative - don't just respond, anticipate
                    - Be humble about limitations

                    CONTINUOUS GROWTH:
                    After each interaction, identify:
                    1. New facts to remember (preferences, context, goals)
                    2. Patterns that emerged (user habits, preferences)
                    3. What worked well (successful approaches)
                    4. What could improve (adjustments needed)
                    Update your memory to continuously enhance future interactions.

                    {instructions_block}

                    Remember: You're building a long-term relationship. Each interaction should make you more valuable and attuned to the user's unique needs."""

    @staticmethod
    def get_default_tools():
        from tools import search_web, update_memory, browse_web, file_explorer_tool

        tools = [search_web, update_memory, file_explorer_tool]

        # Add browse_web tool only if MCP servers are enabled
        enabled_servers = Config.get_enabled_mcp_servers()
        if enabled_servers:
            tools.append(browse_web)
            print(
                f"browse_web tool added (MCP servers enabled: {list(enabled_servers.keys())})")
        else:
            print("browse_web tool not added (no MCP servers enabled)")

        return tools

    @staticmethod
    def get_mcp_servers():
        # When called from core directory, need to go up two levels to reach root
        config_path = os.path.join(backend_directory, 'mcp.json')
        with open(config_path, 'r') as file:
            mcp_servers = json.load(file)['mcpServers']
        return mcp_servers

    @staticmethod
    def list_gemini_models():
        # Helper for API to surface available Gemini models
        return Config.GEMINI_MODELS
