import requests
import json

base_api = "http://127.0.0.1:5000"

def main():
    payload = {
        "message": "Use the MCP web browser agent to open https://example.com and report the title step by step.",
        "session_id": "manual-progress-watch-1"
    }
    with requests.post(base_api + "/api/chat", json=payload, stream=True) as response:
        print("status:", response.status_code)
        for line in response.iter_lines():
            if not line:
                continue
            try:
                data = json.loads(line.decode("utf-8"))
            except json.JSONDecodeError:
                print("bad line:", line)
                continue
            t = data.get("type")
            if t == "mcp_progress":
                print("mcp_progress:", data.get("content"))
            else:
                print(t, data.get("content"))

if __name__ == "__main__":
    main()

