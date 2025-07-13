import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final model = GenerativeModel(
      model: 'gemini-2.5-flash-lite-preview-06-17',
      apiKey: "YOUR_GEMINI_API_KEY",
      systemInstruction: Content.system(
          "You are a helpful, friendly assistant who always try to keep its answers short, concise and to the point"));

  List<Content> history = [];

  List<Map<String, String?>> getHistory() {
    return history.map((entry) {
      final text =
          entry.parts.whereType<TextPart>().map((tp) => tp.text).join();
      return {
        'role': entry.role,
        'content': text,
      };
    }).toList();
  }

  Future<String> chat(String prompt) async {
    final chat = await model.startChat(history: history);
    final message = Content('user', [TextPart(prompt)]);
    try {
      final response = await chat.sendMessage(message);
      print(response.text);
      return response.text ?? '';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
