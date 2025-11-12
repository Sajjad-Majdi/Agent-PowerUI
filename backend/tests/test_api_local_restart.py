import sys
import os
import time
import requests
import subprocess
import threading

PROJECT_ROOT = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

os.chdir(PROJECT_ROOT)


def start_backend_server():
    """Start Flask backend server in background"""
    process = subprocess.Popen(
        [sys.executable, "-u", "backend/api.py"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=PROJECT_ROOT
    )
    return process


def wait_for_server(max_wait=30):
    """Wait for server to be ready"""
    start = time.time()
    while time.time() - start < max_wait:
        try:
            resp = requests.get("http://localhost:5000/api/health", timeout=2)
            if resp.status_code == 200:
                return True
        except:
            pass
        time.sleep(0.5)
    return False


def test_local_agent_restart():
    """Test restarting local agent multiple times through API"""
    server = start_backend_server()
    try:
        if not wait_for_server():
            raise RuntimeError("Backend server failed to start")

        model = "Qwen3-4B-Instruct-2507-Q4_K_M.gguf"

        # First start
        print("Starting first time...")
        resp = requests.post(
            "http://localhost:5000/api/local/start",
            json={"model": model},
            timeout=60
        )
        print(
            f"First start status: {resp.status_code}, body: {resp.text[:200]}")
        assert resp.status_code == 200, f"First start failed: {resp.text}"

        # Check status
        resp = requests.get(
            "http://localhost:5000/api/local/status", timeout=5)
        status1 = resp.json()
        print(f"Status after first start: {status1}")
        assert status1.get("running") == True

        # Stop
        print("Stopping...")
        resp = requests.post(
            "http://localhost:5000/api/local/stop", timeout=30)
        print(f"Stop status: {resp.status_code}, body: {resp.text[:200]}")
        assert resp.status_code == 200

        # Check status after stop
        resp = requests.get(
            "http://localhost:5000/api/local/status", timeout=5)
        status2 = resp.json()
        print(f"Status after stop: {status2}")
        assert status2.get("running") == False

        # Wait a bit for cleanup
        time.sleep(2)

        # Second start - this is where it fails
        print("Starting second time...")
        resp = requests.post(
            "http://localhost:5000/api/local/start",
            json={"model": model},
            timeout=60
        )
        print(
            f"Second start status: {resp.status_code}, body: {resp.text[:200]}")
        if resp.status_code != 200:
            print(f"ERROR: Second start failed with: {resp.text}")
            raise AssertionError(f"Second start failed: {resp.text}")

        # Check final status
        resp = requests.get(
            "http://localhost:5000/api/local/status", timeout=5)
        status3 = resp.json()
        print(f"Status after second start: {status3}")
        assert status3.get("running") == True

        print("SUCCESS: Both starts worked!")

    finally:
        # Cleanup
        try:
            requests.post("http://localhost:5000/api/local/stop", timeout=5)
        except:
            pass
        server.terminate()
        server.wait(timeout=5)
        if server.poll() is None:
            server.kill()


if __name__ == "__main__":
    test_local_agent_restart()
