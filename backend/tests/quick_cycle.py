import requests
import time

BASE = 'http://localhost:5000/api'
model = 'Qwen3-4B-Instruct-2507-Q4_K_M.gguf'

print('list models', requests.get(f'{BASE}/list_models').status_code)

print('start 1', requests.post(
    f'{BASE}/local/start', json={'model': model}).status_code)
print('stop 1', requests.post(f'{BASE}/local/stop').status_code)
print('start 2', requests.post(f'{BASE}/local/start', json={'model': model}
                               ).status_code, requests.post(f'{BASE}/local/start', json={'model': model}).text)
