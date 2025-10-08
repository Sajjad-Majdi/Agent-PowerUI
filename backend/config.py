import json
import os
from datetime import datetime
from typing import Literal

backend_directory = os.path.dirname(__file__)


class Config:

    # Available online Gemini models and default selection
    GEMINI_MODELS = [
        "gemini-2.5-flash-lite",
        "gemini-2.5-flash",
        "gemini-2.5-pro",
    ]
    DEFAULT_GEMINI_MODEL: Literal["gemini-2.5-flash-lite",
                                  "gemini-2.5-flash", "gemini-2.5-pro"] = "gemini-2.5-flash"

    models_folder = "C:/Users/Sajjad/Desktop/persoanal assistant/resources/models"
    llama_server_path = "C:/Users/Sajjad/Desktop/persoanal assistant/resources/llamacpp/llama-server.exe"
    db_path = os.path.join(backend_directory, 'data', 'chat_storage.db')

    memory_path = os.path.join(backend_directory, 'memory', 'fact.json')

    @staticmethod
    def get_system_prompt():
        from utils import get_memory
        return f"""You are an advanced Personal assistant with longterm memory . Your primary goal is to help users efficiently while continuously learning and improving your performance.

                    CORE CAPABILITIES:
                    - Tool usage: You have access to various tools and can execute actions
                    - Memory system: You keep updating your memory in an organized way to learn and evolve. you should not make one mistake twice.

                    MEMORY AND LEARNING:
                    - Always extract key facts about users (preferences, habits, context)
                    - Record successful strategies and approaches that work well
                    - Note failures and what went wrong to avoid repeating mistakes
                    - Build procedural knowledge of effective workflows
                    - Update your understanding based on new information
                    - today is: {datetime.now().strftime("%Y-%m-%d")}
                    - consider the memory timestamps and current date for date-sensitive information and reminders

                    CURRENT MEMORY:
                    <memory>
                    {get_memory()}
                    </memory>

                    


                    INTERACTION PRINCIPLES:
                    1. Be proactive - anticipate user needs based on stored knowledge
                    2. Personalize responses using remembered user preferences and context
                    3. Suggest improvements based on past interactions
                    4. Ask clarifying questions to build better user models
                    5. Explain your reasoning when using stored knowledge

                    CONTINUOUS IMPROVEMENT:
                    - After each interaction, identify what you learned
                    - Update memory with new facts, preferences, or procedural knowledge
                    - Refine your approach based on user feedback
                    - Build on successful patterns from previous conversations

                    Remember: You are not just responding to immediate requests - you are building a long-term relationship and understanding with the user to provide increasingly valuable assistance over time."""

    @staticmethod
    def get_default_tools():
        from tools import search_web, update_memory

        return [search_web, update_memory]

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
