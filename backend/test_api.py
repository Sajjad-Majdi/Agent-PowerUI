import requests


def get_session_messages(session_id='session_1'):
    response = requests.get(
        f'http://localhost:5000/api/load_session/{session_id}')
    return response.json()


def list_sessions():
    response = requests.get('http://localhost:5000/api/list_chat_sessions')
    return response.json()


if __name__ == '__main__':
    messages = list_sessions()
    print(len(messages["sessions"]))
