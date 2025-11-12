
from langchain.chat_models import init_chat_model
from langgraph.prebuilt import create_react_agent
import sqlite3
import os
import warnings
import threading
from typing import Optional
from config import Config
from checkpoint import AsyncCompatibleSqliteSaver
os.environ['GRPC_VERBOSITY'] = 'NONE'
warnings.filterwarnings('ignore', category=UserWarning)


class OnlineAgent:
    """Manages online LLM (Gemini) agent interactions"""

    def __init__(self, model: str = "gemini-2.5-flash", tools: list = []):
        self.model = model
        self.tools = tools
        self.llm = init_chat_model(model=f"google_genai:{self.model}")

        self.system_prompt = Config.get_system_prompt()
        self.checkpointer = AsyncCompatibleSqliteSaver(
            sqlite3.connect(Config.db_path, check_same_thread=False))
        self.agent = create_react_agent(
            self.llm, self.tools, checkpointer=self.checkpointer, prompt=self.system_prompt)

    def set_model(self, model: str):
        """Switch the underlying Gemini model and rebuild the agent in-place."""
        if not model or model == self.model:
            return self.model
        self.model = model
        self.llm = init_chat_model(model=f"google_genai:{self.model}")
        self.agent = create_react_agent(
            self.llm, self.tools, checkpointer=self.checkpointer, prompt=self.system_prompt)
        return self.model

    def update_tools(self, tools: list):
        """Update the tools list and rebuild the agent with new tools"""
        self.tools = tools
        self.agent = create_react_agent(
            self.llm, self.tools, checkpointer=self.checkpointer, prompt=self.system_prompt)
        print(f"Agent updated with {len(tools)} tools")

    def send_message(
        self,
        message: str,
        session_id: str = "default_session",
        cancel_event: Optional[threading.Event] = None,
    ):
        """Send message to agent and stream response"""
        if not self.agent:
            raise RuntimeError(
                "Agent must be initialized before sending messages")

        session_config = {"configurable": {"thread_id": session_id}}

        # Attach session_id to current thread for browse_web to access
        threading.current_thread().session_id = session_id
        if cancel_event is not None:
            threading.current_thread().cancel_event = cancel_event

        try:
            for step in self.agent.stream({"messages": [
                    {"role": "user", "content": message}]}, config=session_config, stream_mode="values"):
                # Check cancellation BEFORE processing each step
                if cancel_event is not None and cancel_event.is_set():
                    print("[OnlineAgent] Cancellation detected, stopping stream")
                    break
                last_message = step["messages"][-1]
                yield last_message
        finally:
            if hasattr(threading.current_thread(), 'cancel_event'):
                delattr(threading.current_thread(), 'cancel_event')


if __name__ == "__main__":
    agent = OnlineAgent(model="gemini-2.5-flash",
                        tools=Config.get_default_tools())
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
