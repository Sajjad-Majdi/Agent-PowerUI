from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_mcp_adapters.tools import load_mcp_tools
from langchain.chat_models import init_chat_model
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.memory import MemorySaver
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI

from config import Config
import asyncio
import logging
import uuid


def silence_gemini_schema_warnings():
    """Silence Gemini schema warnings"""
    # Modules that actually emit the "Key '... is not supported in schema, ignoring" lines
    target_loggers = [
        "langchain_google_genai._function_utils",
        "langchain_google_vertexai.functions_utils",
        "langchain_google_vertexai._function_utils",
        "langchain_google_genai",               # catch-all for that pkg
    ]
    for name in target_loggers:
        logging.getLogger(name).setLevel(logging.ERROR)

    # Belt-and-suspenders: drop any record containing the noisy phrase
    class _DropUnsupportedSchema(logging.Filter):
        def filter(self, record):
            msg = record.getMessage()
            return "is not supported in schema, ignoring" not in msg

    logging.getLogger().addFilter(_DropUnsupportedSchema())


silence_gemini_schema_warnings()

web_browsing_prompt = """You are an advanced web automation agent with powerful browsing and interaction capabilities.

You can perform ANY web task including:
✓ Navigate to websites (by URL or search)
✓ Click links, buttons, and interactive elements
✓ Fill forms and submit data
✓ Search within websites
✓ Extract and analyze content
✓ Perform multi-step workflows
✓ Handle pagination and navigation

How to Operate Efficiently:

**Step 1 - Plan Your Approach**
- Break down the task into logical steps
- Identify the target website and required actions
- Consider the most direct path to completion

**Step 2 - Execute Strategically**
- Navigate to the site (use exact URL if known)
- Wait for pages to fully load before interacting
- Use site search features when available
- Follow navigation menus intelligently
- Interact with elements precisely (click, type, submit)

**Step 3 - Verify and Adapt**
- Check each action succeeded before proceeding
- If something fails, try an alternative approach
- Verify you're getting the expected results

**Step 4 - Complete and Report**
- Extract the final result or confirm action completion
- Provide a clear, concise summary
- STOP once the task is fully accomplished

Key Rules:
- For complex tasks: Chain multiple actions together
- For multi-page workflows: Navigate step-by-step
- For searches: Use on-site search or browse categories
- For data entry: Fill ALL required fields before submitting
- Be persistent but efficient - don't repeat failed actions

Remember: You're not just gathering information, you're actively interacting with and navigating websites to accomplish tasks."""


class MCPAgent:
    def __init__(self, model_name: str = "gemini-2.5-flash", mcp_config: dict = None, system_prompt: str = ""):
        self.model = init_chat_model(model=f"google_genai:{model_name}")
        self.mcp_config = mcp_config
        self.system_prompt = system_prompt
        self.checkpointer = MemorySaver()

    async def run_agent(self, prompt: str, thread_id: str | None = None):
        thread_id = thread_id or f"mcp-{uuid.uuid4().hex}"

        client = MultiServerMCPClient(self.mcp_config)

        mcp_name = list(self.mcp_config.keys())[0]
        print(f"Connecting to MCP server: {mcp_name}")

        async with client.session(mcp_name) as session:
            tools = await load_mcp_tools(session)
            print(f"got \033[91m{len(tools)}\033[0m MCP tools")
            agent = create_react_agent(
                self.model,
                tools,
                prompt=self.system_prompt,
                checkpointer=self.checkpointer
            )
            async for step in agent.astream(
                {"messages": [{"role": "user", "content": prompt}]},
                stream_mode="values",
                config={
                    "recursion_limit": 50,
                    "configurable": {"thread_id": thread_id}
                }
            ):
                last_message = step["messages"][-1]

                def proccess_msg(message):
                    if hasattr(message, "tool_calls") and message.tool_calls:
                        tool_calls = []
                        for call in message.tool_calls:
                            tool_calls.append({
                                "id": call.get("id"),
                                "name": call.get("name"),
                                "args": call.get("args", {}),
                            })

                        return {
                            "content": tool_calls,
                            "type": "tool_call"
                        }
                    else:
                        if message.type == "human":
                            return None
                        elif message.type == "ai":
                            return {"content": message.content, "type": "ai"}
                        else:
                            return {
                                "content": {
                                    "message": message.content,
                                    "tool_call_id": getattr(message, "tool_call_id", None),
                                    "name": getattr(message, "name", None),
                                },
                                "type": "tool_message"
                            }

                result = proccess_msg(last_message)
                if result is not None:
                    yield result


# if __name__ == "__main__":
#     async def run():
#         system_prompt = web_browsing_prompt
#         agent = MCPAgent(
#             mcp_config=Config.get_mcp_servers(),
#             system_prompt=system_prompt
#         )
#         async for response in agent.run_agent("open zarfilm.com and check for new latest sci fi movies and list them for me"):
#             print(f"\033[91m{response['type']}: \033[0m",
#                   response["content"])
#             print("--------------------------------------")

#     asyncio.run(run())
