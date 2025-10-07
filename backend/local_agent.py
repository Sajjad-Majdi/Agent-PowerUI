import time
import subprocess
import sqlite3
import os
from config import Config
from langchain_openai import ChatOpenAI
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.sqlite import SqliteSaver
from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_mcp_adapters.tools import load_mcp_tools
import asyncio

db_path = Config.db_path
os.makedirs(os.path.dirname(db_path), exist_ok=True)


class LocalAgent:
    """Manages local LLM server and agent interactions"""

    def __init__(self, model_name: str, context_window: int = 8192):
        self.model_name = model_name
        self.context_window = context_window
        self.llama_process = None
        self.agent = None
        self.llm = None
        self.system_prompt = Config.get_system_prompt()
        self.checkpointer = SqliteSaver(
            sqlite3.connect(db_path, check_same_thread=False))

    def start_server(self):
        """Starts the llama-server.exe process"""
        command = [
            Config.llama_server_path,
            '-m', f"{Config.models_folder}/{self.model_name}",
            '--port', '8080',
            '-c', f"{self.context_window}",
            '--n-gpu-layers', '99',
            '--jinja'
        ]

        self.llama_process = subprocess.Popen(
            command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        print("Starting llama-server...")
        time.sleep(10)
        print(f"Started llama-server with PID: {self.llama_process.pid}")

        # Create LLM connection
        self.llm = ChatOpenAI(
            base_url="http://127.0.0.1:8080/v1",
            api_key="dummy",
            model=self.model_name.replace('.gguf', ''),
            temperature=0.7
        )

    def stop_server(self):
        """Terminates the running llama-server process"""
        if self.llama_process and self.llama_process.poll() is None:
            self.llama_process.terminate()
            self.llama_process.wait()
            print("llama-server terminated.")
        else:
            print("No active llama-server process to terminate.")

    def initialize_agent(self, tools: list):
        """Initialize agent with tools"""
        if not self.llm:
            raise RuntimeError(
                "Server must be started before initializing agent")
        self.agent = create_react_agent(
            self.llm, tools, checkpointer=self.checkpointer, prompt=self.system_prompt)
        return self.agent

    async def initialize_agent_with_mcp(self, tools: list, mcp_servers: dict):
        """Initialize agent with MCP tools"""
        if not self.llm:
            raise RuntimeError(
                "Server must be started before initializing agent")

        if mcp_servers and len(mcp_servers) > 0:
            try:
                client = MultiServerMCPClient(mcp_servers)
                server_names = list(mcp_servers.keys())

                async with client.session(server_names[0]) as session:
                    mcp_tools = await load_mcp_tools(session)
                    print(f"Loaded {len(mcp_tools)} MCP tools")
                    all_tools = mcp_tools + tools
                    self.agent = create_react_agent(
                        self.llm, all_tools, checkpointer=self.checkpointer, prompt=self.system_prompt)
                    return self.agent
            except Exception as e:
                print(f"MCP connection failed: {e}, using basic tools only")

        self.agent = create_react_agent(
            self.llm, tools, checkpointer=self.checkpointer, prompt=self.system_prompt)
        return self.agent

    def send_message(self, message: str, session_id: str = "default_session"):
        """Send message to agent and stream response"""
        if not self.agent:
            raise RuntimeError(
                "Agent must be initialized before sending messages")

        session_config = {"configurable": {"thread_id": session_id}}

        for step in self.agent.stream({"messages": [
                {"role": "user", "content": message}]}, config=session_config, stream_mode="values"):
            last_message = step["messages"][-1]
            yield last_message

    def __enter__(self):
        """Context manager entry"""
        self.start_server()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.stop_server()
