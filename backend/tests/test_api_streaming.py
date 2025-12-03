import requests
import json
import uuid

base_api = "http://127.0.0.1:5000"


def test_main_chat_api_streaming():
    payload = {
        "message": "what is quantom phycics. think heavily before answering",
        "session_id": f"test-{uuid.uuid4()}"
    }
    print(f"Sending: {payload['message']}")
    print("-" * 50)

    with requests.post(base_api + "/api/chat", json=payload, stream=True, timeout=120) as response:
        assert response.status_code == 200

        event_count = 0
        # Iterate through streaming lines
        for line in response.iter_lines():
            if line:
                event_count += 1
                try:
                    data = json.loads(line.decode('utf-8'))
                    event_type = data.get("type", "unknown")
                    content = data.get("content", "")

                    if event_type == "tool_message":
                        content_str = str(content)[:100]
                        print(f"[{event_count}] {event_type}: {content_str}")
                    elif event_type == "ai_message":
                        content_str = str(content)[:200]
                        print(f"[{event_count}] {event_type}: {content_str}")
                    elif event_type == "tool_call":
                        print(f"[{event_count}] {event_type}: {content}")
                    else:
                        print(f"[{event_count}] {event_type}: {content}")
                except json.JSONDecodeError:
                    print(f"[{event_count}] Failed to parse JSON: {line}")

    print("-" * 50)
    print(f"Total events received: {event_count}")


if __name__ == "__main__":
    test_main_chat_api_streaming()
