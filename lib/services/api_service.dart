import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '/components/subunits/utilities.dart';

class LocalModelInfo {
  final String name;
  final int sizeBytes;

  const LocalModelInfo({
    required this.name,
    required this.sizeBytes,
  });

  factory LocalModelInfo.fromJson(Map<String, dynamic> json) {
    final sizeValue = json['size_bytes'];
    final int size =
        sizeValue is num ? sizeValue.toInt() : int.tryParse('$sizeValue') ?? 0;
    return LocalModelInfo(
      name: json['name']?.toString() ?? '',
      sizeBytes: size,
    );
  }

  String get humanReadableSize {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = sizeBytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}

class LocalAgentStatus {
  final bool running;
  final String? model;

  const LocalAgentStatus({required this.running, this.model});

  factory LocalAgentStatus.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('running')) {
      return LocalAgentStatus(
        running: json['running'] == true,
        model: json['model']?.toString(),
      );
    }
    final status = json['status']?.toString() ?? '';
    if (status == 'started') {
      return LocalAgentStatus(
        running: true,
        model: json['model']?.toString(),
      );
    }
    if (status == 'stopped') {
      return const LocalAgentStatus(running: false);
    }
    final nested = json['status'];
    if (nested is Map<String, dynamic>) {
      return LocalAgentStatus.fromJson(nested);
    }
    return LocalAgentStatus(
      running: json['running'] == true || status == 'started',
      model: json['model']?.toString(),
    );
  }
}

class LocalModelsResult {
  final List<LocalModelInfo> models;
  final LocalAgentStatus status;

  const LocalModelsResult({required this.models, required this.status});

  factory LocalModelsResult.fromJson(Map<String, dynamic> json) {
    final modelsJson = (json['models'] as List?) ?? const [];
    final models = modelsJson
        .whereType<Map>()
        .map((m) => LocalModelInfo.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    final dynamic statusJson = json['status'];
    Map<String, dynamic> parsedStatus = {};
    if (statusJson is Map) {
      parsedStatus = Map<String, dynamic>.from(statusJson);
    } else if (statusJson is String) {
      parsedStatus = {'status': statusJson};
    }
    return LocalModelsResult(
      models: models,
      status: LocalAgentStatus.fromJson(parsedStatus),
    );
  }
}

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

  static Future<void> deleteMemoryFact(String category, int factId) async {
    await ensureBackendReady();
    final response = await http.delete(
      Uri.parse('$baseUrl/memory/$category/$factId'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete memory fact');
    }
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

  static Future<LocalModelsResult> listLocalModels() async {
    await ensureBackendReady();
    final response = await http.get(Uri.parse('$baseUrl/list_models'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LocalModelsResult.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Failed to list local models');
  }

  static Future<LocalAgentStatus> getLocalAgentStatus() async {
    await ensureBackendReady();
    final response = await http.get(Uri.parse('$baseUrl/local/status'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LocalAgentStatus.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Failed to get local agent status');
  }

  static Future<LocalAgentStatus> startLocalModel(String model) async {
    await ensureBackendReady();
    final response = await http.post(
      Uri.parse('$baseUrl/local/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'model': model}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LocalAgentStatus.fromJson(Map<String, dynamic>.from(data));
    }
    try {
      final error = jsonDecode(response.body);
      if (error is Map && error['error'] != null) {
        throw Exception(error['error']);
      }
    } catch (_) {
      // ignore decode errors
    }
    throw Exception('Failed to start local model');
  }

  static Future<LocalAgentStatus> stopLocalModel() async {
    await ensureBackendReady();
    final response = await http.post(Uri.parse('$baseUrl/local/stop'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LocalAgentStatus.fromJson(Map<String, dynamic>.from(data));
    }
    try {
      final error = jsonDecode(response.body);
      if (error is Map && error['error'] != null) {
        throw Exception(error['error']);
      }
    } catch (_) {
      // ignore decode errors
    }
    throw Exception('Failed to stop local model');
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

  static Future<String> getInstructions() async {
    await ensureBackendReady();
    final response = await http.get(Uri.parse('$baseUrl/instructions'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['instructions'] ?? '';
    }
    throw Exception('Failed to get instructions');
  }

  static Future<void> setInstructions(String instructions) async {
    await ensureBackendReady();
    final response = await http.post(
      Uri.parse('$baseUrl/instructions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'instructions': instructions}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to set instructions: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getGeminiApiKeyStatus() async {
    await ensureBackendReady();
    final response = await http.get(Uri.parse('$baseUrl/gemini_api_key'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get API key status');
  }

  static Future<void> setGeminiApiKey(String apiKey) async {
    await ensureBackendReady();
    final response = await http.post(
      Uri.parse('$baseUrl/gemini_api_key'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'api_key': apiKey}),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to set API key');
    }
  }

  static Future<Map<String, dynamic>> getPathConfig() async {
    await ensureBackendReady();
    final response = await http.get(Uri.parse('$baseUrl/paths'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load path configuration');
  }

  static Future<Map<String, dynamic>> setPathConfig({
    String? modelsFolder,
    String? llamaServerPath,
  }) async {
    await ensureBackendReady();
    final response = await http.post(
      Uri.parse('$baseUrl/paths'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (modelsFolder != null) 'models_folder': modelsFolder,
        if (llamaServerPath != null) 'llama_server_path': llamaServerPath,
      }),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    final body = jsonDecode(response.body);
    throw Exception(body['error'] ?? 'Failed to update path configuration');
  }

  static Future<Map<String, dynamic>> importLocalModel({
    required String path,
  }) async {
    await ensureBackendReady();
    final response = await http.post(
      Uri.parse('$baseUrl/models/import'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'path': path}),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    Map<String, dynamic>? body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {
      // ignore parse issues
    }
    throw Exception(body?['error'] ?? 'Failed to import model');
  }

  static Future<Map<String, dynamic>> deleteLocalModel({
    required String name,
  }) async {
    await ensureBackendReady();
    final response = await http.post(
      Uri.parse('$baseUrl/models/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    Map<String, dynamic>? body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {
      // ignore parse issues
    }
    throw Exception(body?['error'] ?? 'Failed to delete model');
  }
}

void main() async {
  // ANSI color codes for terminal output
  const String cyan = '\x1B[36m';
  const String green = '\x1B[32m';
  const String yellow = '\x1B[33m';
  const String red = '\x1B[31m';
  const String magenta = '\x1B[35m';
  const String bold = '\x1B[1m';
  const String reset = '\x1B[0m';

  print('${cyan}${bold}Waiting for backend to be ready...${reset}');
  await ApiService.ensureBackendReady();
  print('${green}✓ Backend is ready!${reset}\n');

  // Get available models
  print('${cyan}Fetching available models...${reset}');
  final modelsResult = await ApiService.listLocalModels();
  if (modelsResult.models.isEmpty) {
    print('${red}No local models found!${reset}');
    return;
  }

  final model = modelsResult.models.first.name;
  print('${green}Selected model: $model${reset}\n');

  // Test start/stop/chat cycle 3 times
  for (int i = 0; i < 3; i++) {
    print('${cyan}${bold}${'=' * 50}${reset}');
    print(
        '${green}${bold}Iteration ${i + 1}: Starting local agent server...${reset}');
    print('${cyan}${bold}${'=' * 50}${reset}');

    try {
      final status = await ApiService.startLocalModel(model);
      print(
          '${green}✓ Server started! Running: ${status.running}, Model: ${status.model}${reset}');
    } catch (e) {
      print('${red}✗ Failed to start server: $e${reset}');
      continue;
    }

    print(
        '\n${yellow}⏳ Waiting 4 seconds for server to fully initialize...${reset}');
    await Future.delayed(const Duration(seconds: 4));

    // Send a test message
    print('\n${cyan}${bold}Sending test message to local agent...${reset}');
    final sessionId = 'test_iteration_${i + 1}';
    try {
      final response = ApiService.streamChat(
        message:
            'Hello! This is test iteration ${i + 1}. Tell me a very short fun fact about cats.',
        sessionId: sessionId,
        useLocalAgent: true,
      );

      await for (final event in response) {
        final type = event['type'];
        final content = event['content'];

        if (type == 'ai_message' && content != null) {
          print('${green}[AI Response] $content${reset}');
        } else if (type == 'tool_call' && content != null) {
          final toolName = content['name'] ?? 'unknown';
          print('${yellow}[Tool Call] $toolName${reset}');
        } else if (type == 'tool_message' && content != null) {
          final preview = content.toString().length > 100
              ? '${content.toString().substring(0, 100)}...'
              : content.toString();
          print('${cyan}[Tool Output] $preview${reset}');
        } else if (type == 'complete') {
          print('${green}[Complete]${reset}');
        } else if (type == 'error') {
          print('${red}[Error] $content${reset}');
        }
      }
    } catch (e) {
      print('${red}✗ Error during chat: $e${reset}');
    }

    print(
        '\n${red}${bold}Iteration ${i + 1}: Stopping local agent server...${reset}');
    try {
      final status = await ApiService.stopLocalModel();
      print('${red}✓ Server stopped! Running: ${status.running}${reset}');
    } catch (e) {
      print('${red}✗ Failed to stop server: $e${reset}');
    }

    if (i < 2) {
      print(
          '\n${magenta}⏱️  Waiting 1 second before next iteration...${reset}');
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  print('\n${cyan}${bold}${'=' * 50}${reset}');
  print('${green}${bold}All tests completed!${reset}');
  print('${cyan}${bold}${'=' * 50}${reset}');
}
