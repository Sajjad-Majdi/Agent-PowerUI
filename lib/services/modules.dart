import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> sendPrompt(String text) async {
  final url = Uri.parse('http://127.0.0.1:5000/chat');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'message': text}),
  );
  final responseBody = jsonDecode(response.body);
  print("AI: " + responseBody);
  return responseBody;
}

