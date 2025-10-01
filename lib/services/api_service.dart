import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';

  static Stream<Map<String, dynamic>> streamChat({
    required String message,
    String? sessionId,
    String? systemPrompt,
  }) async* {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'session_id': sessionId ?? 'default_session',
        if (systemPrompt != null) 'system_prompt': systemPrompt,
      }),
    );

    if (response.statusCode == 200) {
      final lines = response.body.split('\n');
      for (var line in lines) {
        if (line.startsWith('data: ')) {
          final data = jsonDecode(line.substring(6));
          yield data;
        }
      }
    } else {
      throw Exception('Failed to chat: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> getTools() async {
    final response = await http.get(Uri.parse('$baseUrl/tools'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['tools']);
    }
    throw Exception('Failed to get tools');
  }

  static Future<Map<String, dynamic>> getMemory() async {
    final response = await http.get(Uri.parse('$baseUrl/memory'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['memory'];
    }
    throw Exception('Failed to get memory');
  }

  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['agent_initialized'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
