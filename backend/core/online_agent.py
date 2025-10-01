
from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_mcp_adapters.tools import load_mcp_tools
from langchain.chat_models import init_chat_model
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.memory import MemorySaver


# Local files
from config import Config
from tools import search_web, update_memory

# other
import asyncio
import os
os.environ['GRPC_VERBOSITY'] = 'NONE'


class LangchainAgent:

    def __init__(self, model: str = "gemini-2.5-flash", tools: list = []):
        self.model = model
        self.tools = tools
        self.llm = init_chat_model(model=f"google_genai:{self.model}")
        self.agent = create_react_agent(
            self.llm, self.tools, checkpointer=MemorySaver())

    def send_message(self, message: str, session_config: str = "default_session", cli_chat: bool = False, system_prompt: str = None):

        session_config = {"configurable": {"thread_id": session_config}}
        if system_prompt:
            self.agent.update_state(values={"messages": [
                {"role": "system", "content": system_prompt}]}, config=session_config)

            for step in self.agent.stream({"messages": [
                    {"role": "user", "content": message}]}, config=session_config, stream_mode="values"):
                last_message = step["messages"][-1]

            if cli_chat == True:
                last_message.pretty_print()

            return last_message.content

    def start_cli_chat(self, session_config: str = "default_session", system_prompt: str = None):

        cli_chat = True
        session_config = {"configurable": {"thread_id": session_config}}

        if system_prompt:
            self.agent.update_state(values={"messages": [
                {"role": "system", "content": system_prompt}]}, config=session_config)

        print(
            "\033[92m\n\n ----------- Starting chat session ----------- \n\n\033[0m")
        while True:
            prompt = input("\033[94mYou: \033[0m")
            self.send_message(prompt, session_config,
                              cli_chat, system_prompt)

        print(
            "\033[92m\n\n ----------- Ending chat session ----------- \n\n\033[0m")

    async def _run_agent_async(self, session_config: str = "default_session", cli_chat: bool = False, mcp_server: dict = {}, system_prompt: str = None):
        print("starting chat session ...", flush=True)
        print("connecting to the MCP server ...", flush=True)
        session_config = {"configurable": {"thread_id": session_config}}

        client = MultiServerMCPClient(mcp_server)
        server_name = list(mcp_server.keys())[0]

        async with client.session(server_name) as session:

            tools = await load_mcp_tools(session)
            os.system("cls")
            if tools != []:
                print(
                    "\033[92m✅ Successfully connected to the MCP server !\033[0m")
                print(f"🔧 {str(len(tools))} tools loaded ")

            tools += self.tools
            agent = create_react_agent(
                self.llm, tools, checkpointer=MemorySaver())

            if system_prompt:
                agent.update_state(values={"messages": [
                    {"role": "system", "content": system_prompt}]}, config=session_config)

            print(
                f"\033[95m\n ----------- chat session started -----------\n \033[0m")
            while True:
                message = input("\033[94mwrite your message: \033[0m")
                if message == "exit":
                    break
                if cli_chat == True:
                    async for step in agent.astream({"messages": [
                            {"role": "user", "content": message}]}, config=session_config, stream_mode="values"):
                        last_message = step["messages"][-1]
                        last_message.pretty_print()
                else:
                    res = await agent.ainvoke({"messages": [
                        {"role": "user", "content": message}]}, config=session_config)
                    print(f"\033[91mAI:\033[0m {res['messages'][-1].content}")
        print(
            f"\033[95m\n----------- Ending chat session ----------- \n\033[0m")

    def run_agent_with_mcp(self, session_config: str = "default_session", cli_chat: bool = False, mcp_server: dict = {}, system_prompt: str = None, ):
        asyncio.run(self._run_agent_async(
            session_config, cli_chat, mcp_server, system_prompt))
        return
