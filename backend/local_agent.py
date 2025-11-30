import time
import subprocess
import sqlite3
import os
import threading
import requests
import psutil
from typing import Optional
from config import Config
from langchain_openai import ChatOpenAI
from langgraph.prebuilt import create_react_agent
from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_mcp_adapters.tools import load_mcp_tools
import asyncio
from checkpoint import AsyncCompatibleSqliteSaver

db_path = Config.db_path
os.makedirs(os.path.dirname(db_path), exist_ok=True)


class LocalAgent:
    """Manages local LLM server and agent interactions"""

    def __init__(self, model_name: str, context_window: int = 8192, tools: list = []):
        self.model_name = model_name
        self.context_window = context_window
        self.tools = tools
        self.llama_process = None
        self.agent = None
        self.llm = None
        self.system_prompt = Config.get_system_prompt()
        # Keep a dedicated sqlite connection and close it on shutdown to avoid DB locks on Windows
        self._db_conn = sqlite3.connect(db_path, check_same_thread=False)
        self.checkpointer = AsyncCompatibleSqliteSaver(self._db_conn)
        self._port = 8080

    def start_server(self, startup_timeout: float = 120.0, poll_interval: float = 0.5):
        """Starts the llama-server.exe process or connects to existing one.

        Args:
            startup_timeout: Maximum seconds to wait for the HTTP endpoint to become ready.
            poll_interval: Delay between readiness checks in seconds.
        """
        # If a server is already active on the port, just attach.
        if self._check_port_active():
            print(
                f"[LocalAgent] Detected existing server on port {self._port}, attaching instead of starting new process.")
            if not self.llm:
                self.llm = ChatOpenAI(
                    base_url=f"http://127.0.0.1:{self._port}/v1",
                    api_key="dummy",
                    model=self.model_name.replace('.gguf', ''),
                    temperature=0.7
                )
            return

        # Dynamically select an available port if preferred is unavailable
        self._port = self._find_available_port(preferred=8080)

        model_path = os.path.join(Config.get_models_folder(), self.model_name)

        command = [
            Config.get_llama_server_path(),
            '-m', model_path,
            '--port', str(self._port),
            '-c', f"{self.context_window}",
            '--n-gpu-layers', '99',
            '--jinja'
        ]

        print(
            f"\033[94m model path:\033[0m {model_path}")
        print(f"\033[94m command:\033[0m {str(command)}")

        # Capture stderr for diagnostics on failure (don't spam stdout)
        self.llama_process = subprocess.Popen(
            command,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True
        )

        print("Starting llama-server...")
        if not self._wait_for_server_ready(startup_timeout, poll_interval):
            # Read any stderr output for debugging
            error_output = ""
            try:
                if self.llama_process and self.llama_process.stderr:
                    # Non-blocking read of remaining stderr
                    error_output = self.llama_process.stderr.read()[:2000]
            except Exception:
                pass
            self.stop_server()
            raise RuntimeError(
                f"Failed to start llama-server process. Stderr: {error_output.strip()}")

        print(f"Started llama-server with PID: {self.llama_process.pid}")

        # Create LLM connection
        self.llm = ChatOpenAI(
            base_url=f"http://127.0.0.1:{self._port}/v1",
            api_key="dummy",
            model=self.model_name.replace('.gguf', ''),
            temperature=0.7
        )

    def stop_server(self):
        """Completely shut down any llama.cpp server processes and release resources"""
        terminated = False
        handled_pids = set()

        # Try graceful HTTP shutdown first
        if self._check_port_active():
            try:
                response = requests.post(
                    f"http://127.0.0.1:{self._port}/shutdown", timeout=2)
                if response.status_code in (200, 204):
                    print("Requested llama-server shutdown via HTTP.")
                    terminated = True
            except requests.RequestException:
                pass

        # Terminate owned process if present
        if self.llama_process is not None and self.llama_process.poll() is None:
            try:
                self.llama_process.terminate()
                self.llama_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.llama_process.kill()
                self.llama_process.wait()
            print("Owned llama-server terminated.")
            handled_pids.add(self.llama_process.pid)
            terminated = True

        # Terminate any llama process bound to the configured port
        try:
            for proc in psutil.process_iter(['pid', 'name']):
                pid = proc.info.get('pid')
                if pid in handled_pids:
                    continue
                name = (proc.info.get('name') or "").lower()
                if 'llama' not in name:
                    continue

                try:
                    for conn in proc.net_connections(kind='inet'):
                        if conn.laddr and conn.laddr.port == self._port:
                            proc.terminate()
                            proc.wait(timeout=5)
                            print(
                                f"Terminated llama-server (PID: {pid}) on port {self._port}")
                            handled_pids.add(pid)
                            terminated = True
                            break
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
                except psutil.TimeoutExpired:
                    proc.kill()
                    proc.wait()
                    print(
                        f"Killed llama-server (PID: {pid}) on port {self._port} after timeout")
                    handled_pids.add(pid)
                    terminated = True
        except psutil.Error:
            pass

        # As a final sweep, kill any residual llama/ggml processes regardless of port
        try:
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                pid = proc.info.get('pid')
                if pid in handled_pids:
                    continue
                name = (proc.info.get('name') or "").lower()
                cmdline = " ".join(proc.info.get('cmdline') or []).lower()
                if not any(keyword in (name + " " + cmdline)
                           for keyword in ("llama", "llamacpp", "ggml")):
                    continue
                try:
                    proc.terminate()
                    proc.wait(timeout=5)
                    print(f"Terminated residual llama process (PID: {pid}).")
                    terminated = True
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
                except psutil.TimeoutExpired:
                    proc.kill()
                    proc.wait()
                    print(
                        f"Killed residual llama process (PID: {pid}) after timeout.")
                    terminated = True
        except psutil.Error:
            pass

        if not terminated:
            print("No llama.cpp processes found to terminate.")

        self.llama_process = None
        self.llm = None
        self.agent = None
        # Close sqlite connection to release file locks for next start
        try:
            if hasattr(self, "_db_conn") and self._db_conn:
                self._db_conn.close()
                self._db_conn = None
        except Exception:
            pass

        # Wait until port fully inactive (avoid race on immediate restart)
        port_clear_deadline = time.time() + 10
        while self._check_port_active() and time.time() < port_clear_deadline:
            time.sleep(0.5)
        if self._check_port_active():
            print(
                f"[LocalAgent] Warning: Port {self._port} still active after shutdown attempts.")

    def set_model(self, model_name: str):
        """Switch the underlying model and restart server if needed"""
        if not model_name or model_name == self.model_name:
            return self.model_name

        was_running = self.is_running()
        if was_running:
            self.stop_server()

        self.model_name = model_name

        if was_running:
            self.start_server()
            if self.tools:
                self.initialize_agent(self.tools)

        return self.model_name

    def update_tools(self, tools: list):
        """Update the tools list and rebuild the agent with new tools"""
        self.tools = tools
        if self.agent and self.llm:
            self.agent = create_react_agent(
                self.llm, self.tools, checkpointer=self.checkpointer, prompt=self.system_prompt)
            print(f"Agent updated with {len(tools)} tools")

    def initialize_agent(self, tools: list):
        """Initialize agent with tools"""
        if not self.llm:
            raise RuntimeError(
                "Server must be started before initializing agent")
        self.agent = create_react_agent(
            self.llm, tools, checkpointer=self.checkpointer, prompt=self.system_prompt)
        return self.agent

    def send_message(
            self,
            message: str,
            session_id: str = "default_session",
            cancel_event: Optional[threading.Event] = None,):
        """Send message to agent and stream response"""
        if not self.llm:
            self.start_server()

        if not self.is_running():
            raise RuntimeError(
                "Server must be started before sending messages")

        if not self.agent:
            self.initialize_agent(self.tools)

        session_config = {"configurable": {"thread_id": session_id}}

        # Attach session_id to current thread for MCP agent tools to access
        threading.current_thread().session_id = session_id
        if cancel_event is not None:
            threading.current_thread().cancel_event = cancel_event

        try:
            for step in self.agent.stream({"messages": [
                    {"role": "user", "content": message}]}, config=session_config, stream_mode="values"):
                # Check cancellation BEFORE processing each step
                if cancel_event is not None and cancel_event.is_set():
                    print("[LocalAgent] Cancellation detected, stopping stream")
                    break
                last_message = step["messages"][-1]
                yield last_message
        finally:
            if hasattr(threading.current_thread(), 'cancel_event'):
                delattr(threading.current_thread(), 'cancel_event')

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.stop_server()

    def _check_port_active(self) -> bool:
        """Check if there's an active llama server on the port"""
        try:
            response = requests.get(
                f"http://127.0.0.1:{self._port}/v1/models", timeout=2)
            return response.status_code == 200
        except:
            return False

    def _find_available_port(self, preferred: int = 8080) -> int:
        """Return preferred if free or hosting llama server, else an OS-picked free port."""
        import socket
        # If a llama server is already active on preferred, keep it
        if self._port == preferred and self._check_port_active():
            return preferred
        # Try to bind to preferred
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            s.bind(("127.0.0.1", preferred))
            addr, port = s.getsockname()
            s.close()
            return port
        except OSError:
            try:
                s.close()
            except Exception:
                pass
        # Fallback: let OS choose a free port
        s2 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            s2.bind(("127.0.0.1", 0))
            addr, port = s2.getsockname()
            s2.close()
            return port
        except OSError:
            try:
                s2.close()
            except Exception:
                pass
        # Last resort: keep current port
        return preferred

    def _wait_for_server_ready(self, timeout: float, poll_interval: float) -> bool:
        """Poll until the llama server is accepting HTTP requests or timeout."""
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.llama_process and self.llama_process.poll() is not None:
                return False
            if self._check_port_active():
                return True
            time.sleep(poll_interval)
        return False

    def is_running(self) -> bool:
        """Return True if there's an active server (either owned process or on the port)"""
        process_running = self.llama_process is not None and self.llama_process.poll() is None
        port_active = self._check_port_active()
        return process_running or port_active


if __name__ == "__main__":

    # command = "c:\\Users\\Sajjad\\Desktop\\my projects\\persoanal assistant\\resources\\llamacpp\\llama-server.exe -m c:\\Users\\Sajjad\\Desktop\\my projects\\persoanal assistant\\resources\\models\\Qwen3-4B-Instruct-2507-Q4_K_M.gguf --port 8080 -c 8192 --n-gpu-layers 99 --jinja"
    # process = subprocess.Popen(command, shell=True)
    # print(f"Process started with PID: {process.pid}")
    # time.sleep(15)
    # print(f"Process terminated with PID: {process.pid}")
    # process.terminate()
    # process.wait()
    # print(f"Process terminated with PID: {process.pid}")
    # process.kill()
    # process.wait()
    MODEL = os.path.join(Config.get_models_folder(),
                         "Qwen3-4B-Instruct-2507-Q4_K_M.gguf")
    agent = LocalAgent(model_name=MODEL)
    # agent.start_server()
    # agent.initialize_agent(Config.get_default_tools())

    # agent.stop_server()

    print(agent.is_running())
    print(agent._check_port_active())
    print("=======================================")
    agent.stop_server()
    print(agent.is_running())
    print(agent._check_port_active())
    # for result in agent.send_message("write me a 50 line story about a cat", session_id="te9539823w0rst"):
    #     print(result.content)
