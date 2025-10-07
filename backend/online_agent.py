from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_mcp_adapters.tools import load_mcp_tools
from langchain.chat_models import init_chat_model
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.memory import MemorySaver
from langgraph.checkpoint.sqlite import SqliteSaver
import sqlite3
import asyncio
import os
import warnings
from config import Config
os.environ['GRPC_VERBOSITY'] = 'NONE'
warnings.filterwarnings('ignore', category=UserWarning)

# db_path = Config.db_path
# os.makedirs(os.path.dirname(db_path), exist_ok=True)


class OnlineAgent:
    """Manages online LLM (Gemini) agent interactions"""

    def __init__(self, model: str = "gemini-2.5-flash", tools: list = []):
        self.model = model
        self.tools = tools
        self.llm = init_chat_model(model=f"google_genai:{self.model}")
        self.agent = None
        self.system_prompt = Config.get_system_prompt()
        self.checkpointer = SqliteSaver(
            sqlite3.connect(Config.db_path, check_same_thread=False))
        # MCP metadata for UI: list of loaded tools and grouping by server
        self.mcp_tools = []
        self.mcp_tools_by_server = {}

    def initialize_agent(self):
        """Initialize agent with basic tools"""
        self.agent = create_react_agent(
            self.llm, self.tools, checkpointer=self.checkpointer, prompt=self.system_prompt)
        return self.agent

    async def initialize_agent_with_mcp(self, mcp_servers: dict):
        """Initialize agent with MCP tools"""
        if mcp_servers and len(mcp_servers) > 0:
            try:
                client = MultiServerMCPClient(mcp_servers)
                server_names = list(mcp_servers.keys())

                async with client.session(server_names[0]) as session:
                    mcp_tools = await load_mcp_tools(session)
                    print(f"Loaded {len(mcp_tools)} MCP tools")
                    # capture MCP tools for later listing
                    self.mcp_tools = mcp_tools
                    # best-effort grouping by primary server name
                    try:
                        tool_names = []
                        for t in mcp_tools:
                            # LangChain tools expose .name
                            name = getattr(t, 'name', None) or str(t)
                            tool_names.append(name)
                        if server_names:
                            self.mcp_tools_by_server[server_names[0]
                                                     ] = tool_names
                    except Exception:
                        pass

                    all_tools = mcp_tools + self.tools
                    self.agent = create_react_agent(
                        self.llm, all_tools, checkpointer=self.checkpointer, prompt=self.system_prompt)
                    return self.agent
            except Exception as e:
                print(f"MCP connection failed: {e}, using basic tools only")

        self.agent = create_react_agent(
            self.llm, self.tools, checkpointer=self.checkpointer, prompt=self.system_prompt)
        return self.agent

    def set_model(self, model: str):
        """Switch the underlying Gemini model and rebuild the agent in-place."""
        if not model or model == self.model:
            return self.model
        self.model = model
        self.llm = init_chat_model(model=f"google_genai:{self.model}")
        # Prefer MCP tools if already loaded
        tools = (self.mcp_tools if self.mcp_tools else []) + self.tools
        self.agent = create_react_agent(
            self.llm, tools, checkpointer=self.checkpointer, prompt=self.system_prompt)
        return self.model

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


if __name__ == "__main__":
    agent = OnlineAgent(model="gemini-2.5-flash",
                        tools=Config.get_default_tools())
    agent.initialize_agent()
    print("============ Conversation ============")

    try:
        while True:
            print("\033[94mHuman: \033[0m", end="")
            message = input("")
            for step in agent.send_message(message, session_id="test_3"):
                if hasattr(step, 'tool_calls') and step.tool_calls:
                    for tool_call in step.tool_calls:
                        print(
                            f"\033[93mtool call:\033[0m {tool_call['name']}({tool_call['args']})")
                elif hasattr(step, 'content') and step.content:
                    if step.type == "human":
                        continue
                    elif step.type == "ai":
                        print(f"\033[92mAI:\033[0m {step.content}")
                    else:
                        print(f"\033[95mTool Message:\033[0m {step.content}")
    except (Exception, KeyboardInterrupt) as e:
        print("=============== State ================")
        state = agent.agent.get_state(
            config={"configurable": {"thread_id": "test_3"}})
        for message in state.values["messages"]:
            print(f"------{message.type}------\n{message.content}\n")
    finally:
        print("==== State ====")
        state = agent.agent.get_state(
            config={"configurable": {"thread_id": "test_3"}})
        for message in state.values["messages"]:
            print(f"------{message.type}------\n{message.content}\n")
