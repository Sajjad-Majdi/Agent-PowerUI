from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_mcp_adapters.tools import load_mcp_tools
from langchain.chat_models import init_chat_model
from langgraph.checkpoint.memory import MemorySaver
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, MessagesState, START, END
from langgraph.prebuilt import ToolNode
from typing import Annotated, Any, Dict, List, Optional, Type
from langchain_core.messages import BaseMessage, HumanMessage, SystemMessage
from langgraph.graph.message import add_messages
from langchain_core.pydantic_v1 import BaseModel, Field, ValidationError
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


class MCPAgent:
    def __init__(self, model_name: str = "gemini-2.5-flash", mcp_config: dict = None, extra_tools: List[Any] = None, system_prompt: str = ""):
        """
        Initialize MCP Agent. Automatically uses local llama server if running, 
        otherwise falls back to Gemini.

        Args:
            model_name: Name of the Gemini model (only used if local agent is not running)
            mcp_config: MCP server configuration dictionary
            system_prompt: System prompt for the agent
        """
        # Check if local agent is running and use its LLM instead of Gemini
        try:
            from utils import get_local_agent
            local_agent = get_local_agent()

            if local_agent and local_agent.is_running():
                # Use the local llama server
                self.model = ChatOpenAI(
                    base_url=f"http://127.0.0.1:{local_agent._port}/v1",
                    api_key="dummy",
                    model=local_agent.model_name.replace('.gguf', ''),
                    temperature=0.7
                )
                print(
                    f"[MCPAgent] Using local llama server: {local_agent.model_name}")
            else:
                # Fall back to Gemini
                self.model = init_chat_model(
                    model=f"google_genai:{model_name}")
                print(f"[MCPAgent] Using Gemini model: {model_name}")
        except Exception as e:
            # If anything fails, fall back to Gemini
            self.model = init_chat_model(model=f"google_genai:{model_name}")
            print(f"[MCPAgent] Fallback to Gemini due to error: {e}")

        self.mcp_config = mcp_config
        self.system_prompt = system_prompt
        self.checkpointer = MemorySaver()
        self.agent = None
        self.extra_tools = extra_tools or []
        self.thread_id = f"mcp-{uuid.uuid4().hex}"

    def print_state(self):
        if self.agent is not None:
            state_snapshot = self.agent.get_state(
                {"configurable": {"thread_id": self.thread_id}})
            messages = state_snapshot.values.get("messages", [])

            print("\033[96m", "\n" + "="*60, "\033[0m")
            print("\033[96m📊 AGENT STATE - MESSAGE HISTORY\033[0m")
            print("\033[96m", "="*60, "\033[0m")

            for i, msg in enumerate(messages, 1):
                # Color codes
                colors = {
                    "human": "\033[94m",      # Blue
                    "ai": "\033[92m",         # Green
                    "tool": "\033[93m",       # Yellow
                    "system": "\033[95m",     # Magenta
                }
                reset = "\033[0m"

                msg_type = msg.type
                color = colors.get(msg_type, "\033[97m")  # Default white

                # Truncate content
                content = str(msg.content)
                max_length = 100
                truncated = content[:max_length] + \
                    "..." if len(content) > max_length else content

                print(f"\n{color}[{i}] {msg_type.upper()}{reset}")
                print(f"    {truncated}")

                # Show tool call info if present
                if hasattr(msg, "tool_calls") and msg.tool_calls:
                    print(f"    🔧 Tool calls: {len(msg.tool_calls)}")

            print("\n" + "="*60 + "\n")
            return messages
        else:
            print("\033[91m❌ Agent not initialized\033[0m")
            return None

    def prune_old_tool_messages(self, messages, keep_last_n: int = 3):
        """Remove tool messages older than the last N tool messages from message list"""
        # Find indices of all tool messages
        tool_message_indices = [
            i for i, msg in enumerate(messages) if msg.type == "tool"
        ]

        if len(tool_message_indices) > keep_last_n:
            # Identify indices to remove (all but last N tool messages)
            indices_to_remove = set(tool_message_indices[:-keep_last_n])

            # Filter out old tool messages
            pruned_messages = [
                msg for i, msg in enumerate(messages) if i not in indices_to_remove
            ]
            return pruned_messages

        return messages

    def create_custom_agent_graph(self, tools):
        """Create a custom ReAct agent graph with message pruning"""

        def prune_messages_reducer(left: list[BaseMessage], right: list[BaseMessage]) -> list[BaseMessage]:
            """Custom reducer that prunes old tool messages while adding new messages"""
            # First, add new messages using default behavior
            merged = add_messages(left, right)

            # Then prune old tool messages
            tool_indices = [i for i, msg in enumerate(
                merged) if msg.type == "tool"]

            if len(tool_indices) > 3:
                # Keep only last 3 tool messages
                indices_to_remove = set(tool_indices[:-3])
                merged = [msg for i, msg in enumerate(
                    merged) if i not in indices_to_remove]

            return merged

        # Define state with custom reducer
        class AgentState(MessagesState):
            messages: Annotated[list[BaseMessage], prune_messages_reducer]

        # Define the agent node
        def call_model(state: AgentState):
            messages = state["messages"]
            response = self.model.bind_tools(tools).invoke(messages)
            return {"messages": [response]}

        # Define conditional edge logic
        def should_continue(state: AgentState):
            messages = state["messages"]
            last_message = messages[-1]
            if hasattr(last_message, "tool_calls") and last_message.tool_calls:
                return "tools"
            return END

        # Build the graph
        workflow = StateGraph(AgentState)

        # Add nodes
        workflow.add_node("agent", call_model)
        workflow.add_node("tools", ToolNode(tools))

        # Add edges
        workflow.add_edge(START, "agent")
        workflow.add_conditional_edges("agent", should_continue, {
                                       "tools": "tools", END: END})
        workflow.add_edge("tools", "agent")

        # Compile with checkpointer
        return workflow.compile(checkpointer=self.checkpointer)

    async def run_agent(self, prompt: str, thread_id: str | None = None):
        thread_id = thread_id or self.thread_id

        client = MultiServerMCPClient(self.mcp_config)

        mcp_name = list(self.mcp_config.keys())[0]
        print(f"Connecting to MCP server: {mcp_name}")

        async with client.session(mcp_name) as session:
            mcp_tools = await load_mcp_tools(session)
            print(f"got \033[91m{len(mcp_tools)}\033[0m MCP tools")
            tools = mcp_tools + self.extra_tools
            # Create custom agent with pruning
            self.agent = self.create_custom_agent_graph(tools)

            async for step in self.agent.astream(
                {"messages": [{"role": "user", "content": prompt}]},
                stream_mode="values",
                config={
                    "recursion_limit": 50,
                    "configurable": {"thread_id": thread_id}
                }
            ):
                last_message = step["messages"][-1]
                print("Actual type:", last_message.type)

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


class MCPAgentMetadataSchema(BaseModel):
    name: str = Field(..., description="Concise, memorable display name (3-5 words) for the MCP agent.")
    description: str = Field(
        ..., description="One to two sentences explaining what this agent does for the primary assistant.")
    system_prompt: str = Field(
        ..., description="Detailed operating instructions for the MCP agent, including style and safety guidance.")


def get_structured_output_from_gemini(
    schema: Type[BaseModel],
    messages: List[BaseMessage],
    model_name: Optional[str] = None,
):
    """Invoke Gemini with structured output, returning the parsed schema instance."""
    selected_model = model_name or f"google_genai:{Config.DEFAULT_GEMINI_MODEL}"
    llm = init_chat_model(model=selected_model)
    structured_llm = llm.with_structured_output(schema)
    return structured_llm.invoke(messages)


def generate_mcp_agent_metadata(
    server_name: str,
    tools: List[Dict[str, Any]],
    model_name: Optional[str] = None,
) -> Dict[str, str]:
    """Ask Gemini to craft metadata for an MCP agent based on its exposed tools."""
    tool_lines = []
    for tool in tools:
        tool_name = tool.get('name', 'Unnamed tool')
        description = tool.get('description') or tool.get(
            'docstring') or 'No description provided.'
        tool_lines.append(f"- {tool_name}: {description}")

    tools_block = "\n".join(tool_lines) if tool_lines else "- No tools listed"

    system_message = SystemMessage(content=(
        "You are a planner that defines metadata for delegated Model Context Protocol (MCP) agents."
        " Produce polished, human-friendly outputs and never leave fields blank."
    ))

    human_message = HumanMessage(content=(
        f"Server identifier: {server_name}\n"
        f"The MCP agent exposes the following tools:\n{tools_block}\n\n"
        "Provide a display name, a short description so the main assistant knows when to call it,"
        " and a rigorous system prompt that instructs the MCP agent how to operate."
        " Keep the description under 200 characters and the system prompt under 500 words."
    ))

    try:
        result = get_structured_output_from_gemini(
            MCPAgentMetadataSchema,
            [system_message, human_message],
            model_name=model_name,
        )

        if isinstance(result, MCPAgentMetadataSchema):
            return result.dict()
        if isinstance(result, dict):
            return MCPAgentMetadataSchema(**result).dict()
        return result
    except (ValidationError, Exception) as exc:
        raise RuntimeError(f"Failed to generate MCP agent metadata: {exc}")


if __name__ == "__main__":
    async def run():
        system_prompt = "You are a web browsing agent. Navigate and interact with websites to fulfill user requests."
        try:
            agent = MCPAgent(
                mcp_config=Config.get_mcp_servers(),
                system_prompt=system_prompt
            )
            async for response in agent.run_agent("go to zarfilm website and find latest sci fi movies"):
                # Truncate content to first 100 chars
                content = str(response["content"])
                truncated_content = content[:100] + \
                    "..." if len(content) > 100 else content
                print(f"\033[91m{response['type']}: \033[0m",
                      truncated_content)
                print("--------------------------------------")
        except Exception as e:

            agent.print_state()
        finally:
            agent.print_state()

    asyncio.run(run())
