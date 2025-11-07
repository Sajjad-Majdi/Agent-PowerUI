import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '/components/subunits/utilities.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';

  // Caches readiness across concurrent callers so they all await the same future
  static Future<void>? _backendReadyFuture;

  static Future<void> ensureBackendReady({Duration? timeout}) {
    if (_backendReadyFuture != null) return _backendReadyFuture!;
    _backendReadyFuture = _waitForBackend(timeout: timeout);
    return _backendReadyFuture!;
  }

  static Future<void> _waitForBackend({Duration? timeout}) async {
    final Duration maxWait = timeout ?? const Duration(seconds: 60);
    final DateTime start = DateTime.now();
    Duration delay = const Duration(milliseconds: 200);
    while (true) {
      try {
        final health = await healthCheck();
        if (health['status'] == 'healthy') {
          return;
        }
      } catch (_) {
        // ignore and retry
      }
      if (DateTime.now().difference(start) >= maxWait) {
        throw TimeoutException('Backend not ready after ${maxWait.inSeconds}s');
      }
      await Future.delayed(delay);
      // Exponential backoff up to 2s
      final int nextMs = (delay.inMilliseconds * 2).clamp(200, 2000);
      delay = Duration(milliseconds: nextMs);
    }
  }

  static Stream<Map<String, dynamic>> streamChat({
    required String message,
    String? sessionId,
    bool useLocalAgent = false,
    String? model,
  }) async* {
    await ensureBackendReady();
    final endpoint = useLocalAgent ? '$baseUrl/chat/local' : '$baseUrl/chat';

    final client = http.Client();
    final request = http.Request('POST', Uri.parse(endpoint))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'message': message,
        'session_id': sessionId ?? 'default_session',
        if (model != null) 'model': model,
      });

    final response = await client.send(request);

    if (response.statusCode == 200) {
      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.last;

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isNotEmpty) {
            final data = jsonDecode(line);
            yield data;
          }
        }
      }

      if (buffer.trim().isNotEmpty) {
        final data = jsonDecode(buffer.trim());
        yield data;
      }
    } else {
      throw Exception('Failed to chat: ${response.statusCode}');
    }
  }

  static Future<void> cancelChat({String? sessionId}) async {
    await ensureBackendReady();
    final response = await http.post(
      Uri.parse('$baseUrl/chat/stop'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sessionId ?? 'default_session'}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel chat: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> getTools() async {
    await ensureBackendReady();
    final response = await http.get(Uri.parse('$baseUrl/tools'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Merge core tools and attach MCP groups if present
      final coreTools = List<Map<String, dynamic>>.from(data['tools'] ?? []);
      final mcp = data['mcp'];
      if (mcp != null && mcp['servers'] is List) {
        for (final server in mcp['servers']) {
          final name = server['name'] ?? 'MCP';
          final enabled = server['enabled'] ?? true;
          final tools = (server['tools'] as List?)
                  ?.map((t) => t['name'].toString())
                  .toList() ??
              [];
          coreTools.add({
            'name': name,
            'mcp': true,
            'enabled': enabled,
            'tools': tools,
          });
        }
      }
      return coreTools;
    }
    throw Exception('Failed to get tools');
  }

  static Future<Map<String, dynamic>> getMemory() async {
    await ensureBackendReady();
    final response = await http.get(Uri.parse('$baseUrl/memory'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['memory'];
    }
    throw Exception('Failed to get memory');
  }

  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': data['status'],
          'online_agent_initialized': data['online_agent_initialized'] == true,
          'local_agent_initialized': data['local_agent_initialized'] == true,
        };
      }
      return {
        'status': 'error',
        'online_agent_initialized': false,
        'local_agent_initialized': false,
      };
    } catch (e) {
      return {
        'status': 'error',
        'online_agent_initialized': false,
        'local_agent_initialized': false,
      };
    }
  }

  static Future<List<Map<String, dynamic>>> listChatSessions() async {
    await ensureBackendReady();
    final response = await http.get(Uri.parse('$baseUrl/list_chat_sessions'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List sessions = data['sessions'] ?? [];
      return sessions.map((s) {
        if (s is Map) {
          final id = s['id']?.toString() ?? '';
          final name = s['name']?.toString() ?? id;
          return {'id': id, 'name': name};
        } else {
          final id = s.toString();
          return {'id': id, 'name': id};
        }
      }).toList();
    }
    throw Exception('Failed to list chat sessions');
  }

  static Future<List<ChatMessage>> loadSession(String sessionId) async {
    await ensureBackendReady();
    final response =
        await http.get(Uri.parse('$baseUrl/load_session/$sessionId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final messages = data['messages'] as List;
      return messages.map((msg) {
        final toolCalls = msg['tool_calls'] as List?;

        // If this message has tool calls, reconstruct the format with placeholders
        if (toolCalls != null && toolCalls.isNotEmpty) {
          final toolCallStates = <String, ToolCallState>{};
          String contentWithPlaceholders = msg['content'] ?? '';

          for (final toolCall in toolCalls) {
            final toolId = toolCall['id'] ?? '';
            final toolName = toolCall['name'] ?? 'Unknown Tool';
            final toolArgs = Map<String, dynamic>.from(toolCall['args'] ?? {});

            // Add placeholder to content
            contentWithPlaceholders += '<tool_call id="$toolId"></tool_call>';

            // Create tool call state
            toolCallStates[toolId] = ToolCallState(
              toolName: toolName,
              toolArgs: toolArgs,
              status: 'done',
              steps: const <ToolStepState>[],
            );
          }

          return ChatMessage(
            text: contentWithPlaceholders,
            isMe: false,
            toolCallStates: toolCallStates,
          );
        }

        return ChatMessage(
          text: msg['content'] ?? '',
          isMe: msg['is_user'] == true,
        );
      }).toList();
    }
    throw Exception('Failed to load session');
  }

  static Future<String> deleteSession(String sessionId) async {
    await ensureBackendReady();
    final response =
        await http.delete(Uri.parse('$baseUrl/delete_session/$sessionId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message'];
    }
    throw Exception('Failed to delete session: ${response.statusCode}');
  }

  static Future<List<String>> listLocalModels() async {
    await ensureBackendReady();
    final response = await http.get(Uri.parse('$baseUrl/list_models'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['models']);
    }
    throw Exception('Failed to list local models');
  }

  static Future<Map<String, dynamic>> getGeminiModels() async {
    await ensureBackendReady();
    final response = await http.get(Uri.parse('$baseUrl/gemini_models'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get Gemini models');
  }

  static Future<String> setGeminiModel(String model) async {
    await ensureBackendReady();
    final response = await http.post(
      Uri.parse('$baseUrl/set_model'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'model': model}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['model'];
    }
    throw Exception('Failed to set model: ${response.statusCode}');
  }

  static Future<bool> toggleMcpServer(String serverName, bool enabled) async {
    await ensureBackendReady();
    final response = await http.post(
      Uri.parse('$baseUrl/mcp/toggle'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'server_name': serverName,
        'enabled': enabled,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['enabled'] == true;
    }
    throw Exception('Failed to toggle MCP server: ${response.statusCode}');
  }
}

void main() async {
  final sessionId = 'test_532349';
  final response = ApiService.streamChat(
      message:
          'use the browsing tool and search for the weather in Tehran tomorrow',
      sessionId: sessionId);
  await for (final event in response) {
    final type = event['type'];
    final content = event['content'];
    if (content != null) {
      if (type == 'tool_message') {
        print('[$type] ${content.substring(0, 100)}...');
      } else {
        print('[$type] $content');
      }
    } else {
      print('[$type]');
    }
  }
}
