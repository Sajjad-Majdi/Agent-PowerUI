import subprocess
import sys
import json
from transformers import AutoProcessor
import base64
import mimetypes


def ollama_run(model_id=None):

    # models = list_models()

    # if model_id not in [model['NAME'] for model in models]:
    #     raise ValueError(f"Model {model_id} not found. the model_id is either wrong or not downloaded.")

    try:
        creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        subprocess.Popen(
            ['ollama', 'run', model_id],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=creationflags
        )
        print(f"{model_id} is loading in background.")
    except Exception as e:
        print(f"Error loading the model: {e}")


def list_models():
    try:
        result = subprocess.run(
            ['ollama', 'list'],
            check=True,
            text=True,
            capture_output=True
        )
        output = result.stdout
        lines = output.strip().splitlines()
        models = []
        # Skip header (first line)
        for line in lines[1:]:
            if not line.strip():
                continue
            tokens = line.split()
            # Expect at least: NAME, ID, size_value, size_unit
            if len(tokens) < 4:
                continue
            name = tokens[0]
            size = tokens[2] + ' ' + tokens[3]
            models.append({'NAME': name, 'SIZE': size})
        return models
    except subprocess.CalledProcessError as e:
        print(f"Error running ollama: {e}")
        raise


def get_base64_data(file_path):
    """
    Converts a file to a base64-encoded data URL suitable for model input.

    Args:
        file_path (str): Path to the file.

    Returns:
        tuple: (mime_type, encoded_string)
    """

    # Guess the MIME type based on the file extension
    mime_type, _ = mimetypes.guess_type(file_path)
    if mime_type is None:
        # Default to binary stream if unknown
        mime_type = "application/octet-stream"

    with open(file_path, "rb") as file:
        encoded_string = base64.b64encode(file.read()).decode("utf-8")

        return mime_type, encoded_string


def load_history(file_path: str = 'history.json') -> list:
    """Read the conversation history from a file.
    Returns:
        list: A list of messages in the conversation.
    """
    try:
        with open(file_path, 'r') as f:
            conversation = json.load(f)
        return conversation
    except FileNotFoundError:
        raise ValueError(
            "History file not found. Please start a new conversation.")


def add_message(role, content):
    """Add a message to the conversation. handle having image or text content."""
    try:
        history = load_history()
    except ValueError:
        history = []

    message = {"role": role, "content": content}
    history.append(message)

    with open('history.json', 'w') as f:
        json.dump(history, f, indent=2)


def supports_image(model_id: str) -> bool:
    """Check if the Hugging Face model supports image input.

     Note: 
     - it downloads the model's config files.
     - it does not load the model weights.
    """
    try:
        proc = AutoProcessor.from_pretrained(model_id, device_map="auto")
        has_image = hasattr(proc, "feature_extractor") or hasattr(
            proc, "image_processor")
        return has_image
    except Exception as e:
        print(f"Error: {e}")
        return False


if __name__ == "__main__":
    ollama_run("gemma3:4b-it-qat")
