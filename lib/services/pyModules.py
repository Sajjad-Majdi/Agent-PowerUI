from utils import get_base64_data, list_models
from smolagents import OpenAIServerModel
import ollama

SYSTEM_PROMPT = """
You are a highly capable and friendly AI assistant. 
Always provide concise, accurate, and helpful responses. 
Communicate in the same language as the user, and adapt your tone to be polite and approachable. If you are unsure about something, clarify or ask for more information rather than guessing.
"""

text_example = '''
معادله دیفرانسیل: /$y' = 2x$

این یک معادله دیفرانسیل مرتبه اول است. $y'$ نماد مشتق $y$ نسبت به $x$ است.

**توضیح:**
این معادله بیان می‌کند که نرخ تغییر $y$ نسبت به $x$ برابر با $2x$ است. برای یافتن تابع $y(x)$، باید از هر دو طرف معادله نسبت به $x$ انتگرال بگیریم:

$\int y' dx = \int 2x dx$

$y(x) = x^2 + C$

که در آن $C$ یک ثابت انتگرال‌گیری است. این نشان می‌دهد که بی‌نهایت تابع وجود دارد که این معادله دیفرانسیل را برآورده می‌کنند، که همگی با یک مقدار ثابت از هم متمایز می‌شوند.

'''


class GeminiHandler:
    def __init__(self, model_name=None, api_key=None):
        self.GEMINI_MODEL = model_name
        # Use provided API key or default
        self.GEMINI_API_KEY = api_key if api_key else "YOUR_GEMINI_API_KEY"
        self.GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta/openai/"
        self.current_conversation_history = []

    def reset_chat(self):
        """Resets the current conversation history."""
        self.current_conversation_history = []
        print("Chat history has been reset.")

    def chat(self, text_prompt: str = None, image_paths: list[str] = None, stream: bool = False):
        """
        Public interface. If stream=True returns a generator of chunks;
        otherwise returns the full response string.
        image_paths can be either file paths or base64 data URLs
        """
        if stream:
            return self._chat_stream(text_prompt, image_paths)
        return self._chat(text_prompt, image_paths)

    def _chat(self, text_prompt: str = None, image_paths: list[str] = None):
        """
        Non-streaming chat: sends the request, waits for full response,
        adds it to history and returns it.
        """
        if not text_prompt and not image_paths:
            print("Error: No input provided (text or image).")
            return None

        user_message_content = []
        if text_prompt:
            user_message_content.append({"type": "text", "text": text_prompt})
        if image_paths:
            for image_path in image_paths:
                if image_path.startswith('data:'):
                    # Already a base64 data URL
                    user_message_content.append({
                        "type": "image_url",
                        "image_url": {"url": image_path}
                    })
                else:
                    # File path - convert to base64
                    mime_type, encoded_string = get_base64_data(image_path)
                    user_message_content.append({
                        "type": "image_url",
                        "image_url": {"url": f"data:{mime_type};base64,{encoded_string}"}
                    })

        if not user_message_content:
            print("Error: User message content is empty after processing inputs.")
            return None

        # record user
        self.current_conversation_history.append({
            "role": "user",
            "content": user_message_content
        })

        model = OpenAIServerModel(
            model_id=self.GEMINI_MODEL,
            api_base=self.GEMINI_API_BASE,
            api_key=self.GEMINI_API_KEY,
        )
        res = model.generate(messages=self.current_conversation_history)
        response_text = res.content

        # record assistant
        self.current_conversation_history.append({
            "role": "assistant",
            "content": response_text
        })
        return response_text

    def _chat_stream(self, text_prompt: str = None, image_paths: list[str] = None):
        """
        Streaming chat: yields each chunk as it arrives,
        then appends the full response to history.
        """
        if not text_prompt and not image_paths:
            print("Error: No input provided (text or image).")
            return

        user_message_content = []
        if text_prompt:
            user_message_content.append({"type": "text", "text": text_prompt})
        if image_paths:
            for image_path in image_paths:
                if image_path.startswith('data:'):
                    # Already a base64 data URL
                    user_message_content.append({
                        "type": "image_url",
                        "image_url": {"url": image_path}
                    })
                else:
                    # File path - convert to base64
                    mime_type, encoded_string = get_base64_data(image_path)
                    user_message_content.append({
                        "type": "image_url",
                        "image_url": {"url": f"data:{mime_type};base64,{encoded_string}"}
                    })

        # record user
        self.current_conversation_history.append({
            "role": "user",
            "content": user_message_content
        })

        model = OpenAIServerModel(
            model_id=self.GEMINI_MODEL,
            api_base=self.GEMINI_API_BASE,
            api_key=self.GEMINI_API_KEY,
        )
        response_text = ""
        for chunk in model.generate_stream(messages=self.current_conversation_history):
            response_text += chunk.content
            yield chunk.content

        # record assistant
        self.current_conversation_history.append({
            "role": "assistant",
            "content": response_text
        })


class OllamaHandler:
    def __init__(self, model_name=None):
        self.MODEL = model_name
        self.current_conversation_history = [{
            "role": "system",
            "content": f"You are {self.MODEL}. {SYSTEM_PROMPT}"
        }]

    def reset_chat(self):
        """Resets the current conversation history."""
        self.current_conversation_history = []
        print("Chat history has been reset.")

    def text_chat(self, text_prompt: str = None):

        if text_prompt:

            self.current_conversation_history.append({
                "role": "user",
                "content": text_prompt
            })

            response_text = ""
            for chunk in ollama.chat(self.MODEL, messages=self.current_conversation_history, stream=True):
                response_text += chunk['message']['content']
                yield chunk['message']['content']

            # record assistant
            self.current_conversation_history.append({
                "role": "assistant",
                "content": response_text
            })

        else:
            print("There is no prompt entered")
            return

    def chat(self, text_prompt: str = None, image_paths: list[str] = None):
        """
        Streaming chat: yields each chunk as it arrives,
        then appends the full response to history.
        """
        if not text_prompt and not image_paths:
            print("Error: No input provided (text or image).")
            return

        user_message_content = []
        if text_prompt:
            user_message_content.append({"type": "text", "text": text_prompt})
        if image_paths:
            for image_path in image_paths:
                if image_path.startswith('data:'):
                    # Already a base64 data URL
                    user_message_content.append({
                        "type": "image_url",
                        "image_url": {"url": image_path}
                    })
                else:
                    # File path - convert to base64
                    mime_type, encoded_string = get_base64_data(image_path)
                    user_message_content.append({
                        "type": "image_url",
                        "image_url": {"url": f"data:{mime_type};base64,{encoded_string}"}
                    })

        # record user
        self.current_conversation_history.append({
            "role": "user",
            "content": user_message_content
        })

        response_text = ""
        for chunk in ollama.chat(self.MODEL, messages=self.current_conversation_history, stream=True):
            response_text += chunk['message']['content']
            yield chunk['message']['content']

        # record assistant
        self.current_conversation_history.append({
            "role": "assistant",
            "content": response_text
        })


if __name__ == "__main__":
    model = OllamaHandler('gemma3n:e4b')
    for chunk in model.text_chat("hi there"):
        print(chunk, flush=True, end="")
