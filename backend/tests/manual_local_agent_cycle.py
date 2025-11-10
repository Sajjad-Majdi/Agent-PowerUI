"""Manual integration test for local agent start/stop cycles via HTTP API.

Run this script while the Flask backend (`backend/api.py`) is up. It will:
  1. Fetch the list of available local models and pick the first one.
  2. Start the selected model three times in a row.
  3. After each start, send a short chat message through the local chat endpoint
     to verify the agent responds.
  4. Stop the local agent and pause briefly before the next iteration.

Usage:
    python -m backend.tests.manual_local_agent_cycle

This script prints concise progress information and basic response payloads so
it is easy to spot failures during manual debugging.
"""

from __future__ import annotations

import json
import time
import requests

BASE_URL = "http://localhost:5000/api"
LOCAL_START = f"{BASE_URL}/local/start"
LOCAL_STOP = f"{BASE_URL}/local/stop"
LOCAL_STATUS = f"{BASE_URL}/local/status"
LOCAL_LIST_MODELS = f"{BASE_URL}/list_models"
LOCAL_CHAT = f"{BASE_URL}/chat/local"


def _print_header(title: str) -> None:
    bar = "=" * 60
    print(f"\n{bar}\n{title}\n{bar}")


def _ensure_backend() -> None:
    """Poll the health endpoint until the backend reports healthy."""
    health_url = f"{BASE_URL}/health"
    deadline = time.time() + 60
    while time.time() < deadline:
        try:
            resp = requests.get(health_url, timeout=2)
            data = resp.json()
            if resp.status_code == 200 and data.get("status") == "healthy":
                return
        except Exception:
            pass
        time.sleep(0.5)
    raise RuntimeError("Backend health check never reached healthy status")


def _pick_model() -> str:
    resp = requests.get(LOCAL_LIST_MODELS, timeout=10)
    resp.raise_for_status()
    payload = resp.json()
    models = payload.get("models") or []
    if not models:
        raise RuntimeError("No local models reported by /list_models")
    name = models[0]["name"]
    print(f"Using local model: {name}")
    return name


def _start_model(model: str) -> dict:
    resp = requests.post(LOCAL_START, json={"model": model}, timeout=120)
    print(f"start -> {resp.status_code} {resp.text[:120]}")
    resp.raise_for_status()
    return resp.json()


def _stop_model() -> dict:
    resp = requests.post(LOCAL_STOP, timeout=30)
    print(f"stop  -> {resp.status_code} {resp.text[:120]}")
    resp.raise_for_status()
    return resp.json()


def _send_chat(message: str, session_id: str) -> None:
    """Send a message to the local chat endpoint and print the streamed chunks."""
    resp = requests.post(
        LOCAL_CHAT,
        json={"message": message, "session_id": session_id},
        stream=True,
        timeout=120,
    )
    if resp.status_code != 200:
        print(f"chat  -> {resp.status_code} {resp.text[:120]}")
        resp.raise_for_status()

    print("chat  -> streaming response...")
    buffer = ""
    for chunk in resp.iter_content(chunk_size=None):
        if not chunk:
            continue
        buffer += chunk.decode("utf-8", errors="ignore")
        while "\n" in buffer:
            line, buffer = buffer.split("\n", 1)
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                print(f"    [raw] {line[:120]}")
                continue
            event_type = data.get("type")
            content = data.get("content")
            if event_type == "ai_message":
                preview = content if isinstance(content, str) else str(content)
                print(f"    [ai ] {preview[:120]}")
            elif event_type == "tool_call":
                name = content.get("name") if isinstance(
                    content, dict) else content
                print(f"    [tool] {name}")
            elif event_type == "tool_message":
                preview = content if isinstance(
                    content, str) else json.dumps(content)
                print(f"    [tool-msg] {preview[:120]}")
            elif event_type == "error":
                print(f"    [err] {content}")
            elif event_type == "complete":
                print("    [done]")
            else:
                print(f"    [{event_type}] {str(content)[:120]}")


def main() -> None:
    _print_header("Checking backend readiness")
    _ensure_backend()

    model = _pick_model()

    for iteration in range(1, 4):
        _print_header(f"Iteration {iteration}: start")
        status = _start_model(model)
        print(f"Running: {status.get('running')} Model: {status.get('model')}")

        print("Waiting 4 seconds for model warm-up...")
        time.sleep(4)

        _print_header(f"Iteration {iteration}: chat")
        _send_chat(
            f"Hello from iteration {iteration}! Give me a short fun fact.",
            session_id=f"manual_test_{iteration}",
        )

        _print_header(f"Iteration {iteration}: stop")
        stop_status = _stop_model()
        print(f"Running after stop: {stop_status.get('running')}")

        if iteration < 3:
            print("Cooldown 1 second before next iteration...")
            time.sleep(1)

    _print_header("All iterations complete")


if __name__ == "__main__":
    main()
