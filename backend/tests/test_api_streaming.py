import requests
import json
import uuid

base_api = "http://127.0.0.1:5000"


def test_main_chat_api_streaming():
    payload = {
        "message": "go to the zarfilm website with browser and see what new sci fi movies have come",
        "session_id": f"test-{uuid.uuid4()}"
    }
    with requests.post(base_api + "/api/chat", json=payload, stream=True) as response:
        assert response.status_code == 200

        # Iterate through streaming lines
        for line in response.iter_lines():
            if line:
                try:
                    data = json.loads(line.decode('utf-8'))
                    if data.get("type") == "tool_message":
                        content = data.get("content", "") or ""
                        output = {"type": "tool_message",
                                  "content": str(content)[:100]}
                        print(output)
                    else:
                        print(data)
                except json.JSONDecodeError:
                    print(f"Failed to parse JSON: {line}")


if __name__ == "__main__":
    test_main_chat_api_streaming()
