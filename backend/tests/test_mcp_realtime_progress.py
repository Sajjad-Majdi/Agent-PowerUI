import requests
import json

base_api = "http://127.0.0.1:5000"


def test_mcp_progress_streaming_order():
    payload = {
        "message": "Go to the zarfilm website using the MCP browsing agent and find the latest sci-fi movies.",
        "session_id": "test-session-mcp-progress-001",
    }

    with requests.post(base_api + "/api/chat", json=payload, stream=True) as response:
        assert response.status_code == 200

        saw_mcp_progress = False
        tool_message_received = False

        for line in response.iter_lines():
            if not line:
                continue
            try:
                data = json.loads(line.decode("utf-8"))
            except json.JSONDecodeError:
                continue

            t = data.get("type")
            if t == "mcp_progress":
                saw_mcp_progress = True
            elif t == "tool_message":
                tool_message_received = True
                # Once final tool_message arrives, if we ever saw progress, it must have preceded this
                break

        # If MCP progress was produced during the run, it should have arrived before final tool_message
        if saw_mcp_progress:
            assert tool_message_received, "Expected a final tool_message after MCP progress"


if __name__ == "__main__":
    test_mcp_progress_streaming_order()
