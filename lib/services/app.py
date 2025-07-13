from flask import Flask, request, jsonify
import requests
from lib.services.pyModules import OllamaHandler
from utils import ollama_run


app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False

ollama_run('gemma3n:e4b')
model = OllamaHandler('gemma3n:e4b')


@app.route('/chat', methods=['POST'])
def chat():
    data = request.json
    message = data.get('message')
    full = ''.join(model.text_chat(message))
    return jsonify(full)


if __name__ == '__main__':
    app.run(debug=True)
