import requests


def get_session_messages(session_id='session_1'):
    response = requests.get(
        f'http://localhost:5000/api/load_session/{session_id}')
    return response.json()


def list_sessions():
    response = requests.get('http://localhost:5000/api/list_chat_sessions')
    return response.json()


def chat_with_ai(message, session_id='session_1343', use_local=False):
    """Send a message to the AI and print streaming responses"""
    endpoint = '/api/chat/local' if use_local else '/api/chat'
    response = requests.post(
        f'http://localhost:5000{endpoint}',
        json={'message': message, 'session_id': session_id},
        stream=True
    )

    for line in response.iter_lines():
        if line:
            data = line.decode('utf-8')
            print(data)


if __name__ == '__main__':
    chat_with_ai("how is the weather in Karaj tommarow?", use_local=False)
