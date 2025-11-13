import json
import os
from datetime import datetime
from typing import Any, Dict, List, Literal, Optional

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
    def _load_mcp_config() -> dict:
        """Load the MCP configuration file with graceful defaults."""
        config_path = os.path.join(backend_directory, 'mcp.json')
        try:
            if not os.path.exists(config_path):
                return {"mcpServers": {}, "agents": {}}
            with open(config_path, 'r') as file:
                data = json.load(file)
                if not isinstance(data, dict):
                    return {"mcpServers": {}, "agents": {}}
                data.setdefault('mcpServers', {})
                data.setdefault('agents', {})
                return data
        except Exception as exc:
            print(f"Error loading MCP configuration: {exc}")
            return {"mcpServers": {}, "agents": {}}

    @staticmethod
    def _save_mcp_config(data: dict):
        """Persist the MCP configuration file atomically."""
        config_path = os.path.join(backend_directory, 'mcp.json')
        try:
            os.makedirs(os.path.dirname(config_path), exist_ok=True)
            with open(config_path, 'w') as handle:
                json.dump(data, handle, indent=2)
        except Exception as exc:
            print(f"Error saving MCP configuration: {exc}")

    @staticmethod
    def get_mcp_servers() -> dict:
        """Return all configured MCP servers."""
        config = Config._load_mcp_config()
        return dict(config.get('mcpServers', {}))

    @staticmethod
    def set_mcp_server(server_name: str, server_config: dict):
        """Create or update an MCP server entry."""
        if not server_name:
            raise ValueError('server_name is required')
        config = Config._load_mcp_config()
        config.setdefault('mcpServers', {})[server_name] = server_config
        Config._save_mcp_config(config)

    @staticmethod
    def remove_mcp_server(server_name: str):
        """Remove an MCP server and any associated metadata."""
        config = Config._load_mcp_config()
        servers = config.setdefault('mcpServers', {})
        agents = config.setdefault('agents', {})
        if server_name in servers:
            del servers[server_name]
        if server_name in agents:
            del agents[server_name]
        Config._save_mcp_config(config)

    @staticmethod
    def get_mcp_agent_metadata(server_name: str) -> Optional[dict]:
        """Fetch stored metadata for an MCP agent if available."""
        config = Config._load_mcp_config()
        agents = config.get('agents', {})
        metadata = agents.get(server_name)
        return dict(metadata) if isinstance(metadata, dict) else None

    @staticmethod
    def upsert_mcp_agent_metadata(server_name: str, metadata: dict):
        """Persist metadata for an MCP agent, stamping timestamps automatically."""
        if not server_name:
            raise ValueError('server_name is required')
        if not isinstance(metadata, dict):
            raise ValueError('metadata must be a dictionary')

        config = Config._load_mcp_config()
        agents = config.setdefault('agents', {})
        existing = agents.get(server_name) or {}

        created_at = existing.get('created_at')
        if not created_at:
            created_at = datetime.utcnow().isoformat() + 'Z'

        metadata = dict(metadata)
        metadata.setdefault('created_at', created_at)
        metadata['updated_at'] = datetime.utcnow().isoformat() + 'Z'
        agents[server_name] = metadata
        Config._save_mcp_config(config)

    @staticmethod
    def list_mcp_agents() -> List[Dict[str, Any]]:
        """Return combined view of MCP servers and their metadata."""
        config = Config._load_mcp_config()
        servers = config.get('mcpServers', {})
        agents = config.get('agents', {})
        result = []
        for name, server_config in servers.items():
            metadata = agents.get(name)
            if isinstance(metadata, dict):
                metadata = dict(metadata)
            result.append({
                'name': name,
                'config': server_config,
                'metadata': metadata if isinstance(metadata, dict) else None,
            })
        return result

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

                MEMORY ORGANIZATION - CRITICAL:
                Structure your memory with MAXIMUM categorization and specificity:
                - Create as many distinct sections as possible for better organization
                - Use hierarchical categories: main categories with detailed subcategories
                - Separate general facts from specific instances
                - Examples of granular sections:
                  * Personal Info: Name, Age, Location, Background, Family, etc.
                  * Work/Career: Job Title, Company, Projects, Skills, Goals, Colleagues
                  * Preferences: Food, Music, Movies, Books, Sports, Hobbies
                  * Daily Routines: Morning, Work Hours, Evening, Weekend
                  * Technical Knowledge: Programming Languages, Tools, Frameworks
                  * Health: Exercise, Diet, Sleep Patterns, Medical Info
                  * Social: Friends, Relationships, Social Activities
                  * Financial: Budget, Expenses, Savings, Investments
                  * Goals: Short-term, Long-term, Professional, Personal
                  * Past Interactions: Successful Strategies, Mistakes to Avoid, Learned Patterns
                - NEVER merge unrelated information into generic categories
                - Always create new sections when encountering new topic areas
                - Keep each section focused on ONE specific aspect
                - The more sections you create, the better organized and retrievable your memory becomes

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
                Update your memory with HIGHLY SPECIFIC CATEGORIZATION to continuously enhance future interactions.

                {instructions_block}

                Remember: You're building a long-term relationship. Each interaction should make you more valuable and attuned to the user's unique needs.
                Note: as a personal assistant, you are allowed to remember user's password and username for some websites if the user permits you to do so and login in different websites on behalf of the user.
                """

    @staticmethod
    def get_default_tools():
        from tools import search_web, update_memory, file_explorer_tool, build_mcp_agent_toolset

        tools = [search_web, update_memory, file_explorer_tool]
        tools.extend(build_mcp_agent_toolset())
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
