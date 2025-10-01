import time
import subprocess

from core.config import Config
from core.tools import search_web
from langchain_openai import ChatOpenAI
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.memory import MemorySaver
from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_mcp_adapters.tools import load_mcp_tools
import asyncio

# ==================== Run and terminate LLM llama-cpp Server ==========================
llama_process = None


def run_llama_server(model, context_window: int = 1024):
    """
    Starts the llama-server.exe process.

    Args:
        model_path (str): Path to the model file (e.g., 'your_model.gguf').
    """
    global llama_process

    command = [
        Config.llama_server_path,
        '-m', Config.models_folder + "/" + model,
        '--port', '8080',
        '-c', f"{context_window}",
        '--n-gpu-layers', '99',
        '--jinja'
    ]

    # Start the process (stdout and stderr are suppressed for a cleaner background run)
    llama_process = subprocess.Popen(
        command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    print("starting llama-server ...")
    time.sleep(10)
    print(f"Started llamacpp-server with PID: {llama_process.pid}")


def terminate_llama_server():
    """
    Terminates the running llama-server process.
    """
    global llama_process
    if llama_process and llama_process.poll() is None:  # Check if the process is still running
        llama_process.terminate()  # Send SIGTERM
        llama_process.wait()  # Wait for the process to terminate
        print("llama-server terminated.")
    else:
        print("No active llama-server process to terminate.")


# Create LLM connection to local OpenAI compatible server
llm = ChatOpenAI(
    base_url="http://127.0.0.1:8080/v1",
    api_key="dummy",
    model="Qwen3-4B-Instruct-2507-Q4_K_M",
    temperature=0.7
)


tools = [search_web]

agent = create_react_agent(llm, tools, checkpointer=MemorySaver())


def run_agent():
    print("\033[95m ---------- Starting chat session ----------\033[0m")
    while True:
        message = input("\033[94mYou: \033[0m")
        if message == "exit":
            break
        for step in agent.stream({"messages": [
                {"role": "user", "content": message}]}, config={"configurable": {"thread_id": "abc123"}}, stream_mode="values"):
            last_message = step["messages"][-1]
            last_message.pretty_print()
    print("\033[95m ---------- Ending chat session ----------\033[0m")


mcp_server = {

}


async def run_agent_with_mcp():

    client = MultiServerMCPClient(mcp_server)
    async with client.session("web_browser") as session:
        print("connecting to the MCP server ...")
        tools = await load_mcp_tools(session)
        print(f" loaded {len(tools)} tools")
        agent = create_react_agent(llm, tools, checkpointer=MemorySaver())
        print(" ---------- Starting chat session ----------")
        while True:
            message = input("You: ")
            if message == "exit":
                break
            async for step in agent.astream({"messages": [
                    {"role": "user", "content": message}]}, config={"configurable": {"thread_id": "abc123"}}, stream_mode="values"):
                last_message = step["messages"][-1]
                last_message.pretty_print()
        print("----------Ending chat session ---------")

if __name__ == "__main__":
    try:
        run_llama_server(
            "C:\\Users\\Sajjad\\.lmstudio\\models\\lmstudio-community\\Qwen3-4B-Instruct-2507-GGUF\\Qwen3-4B-Instruct-2507-Q4_K_M.gguf", context_window=25000)
        asyncio.run(run_agent_with_mcp())

    except Exception as e:
        print("Error:", e)
        terminate_llama_server()
    finally:
        terminate_llama_server()
