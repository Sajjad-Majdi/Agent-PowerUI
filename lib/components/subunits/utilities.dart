import 'package:characters/characters.dart';
import 'package:intl/intl.dart';

// ------------------------------- RTL Checker ---------------------------------
bool isRTL(String text) {
  for (final ch in text.characters) {
    if (ch.trim().isEmpty) continue;
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(ch)) continue;

    return Bidi.hasAnyRtl(ch);
  }
  return false;
}

// ------------------------------- Chat Message Model --------------------------
class ChatMessage {
  String? text;
  final bool isMe;
  bool isLoading;
  Map<String, dynamic>? toolCall;
  Map<String, ToolCallState>? toolCallStates;

  ChatMessage({
    this.text,
    required this.isMe,
    this.isLoading = false,
    this.toolCall,
    this.toolCallStates,
  });
}

class ToolCallState {
  final String toolName;
  final Map<String, dynamic> toolArgs;
  final String status; // 'in_progress', 'done', 'error'
  final List<ToolStepState> steps;
  final String? currentTool;
  final String? resultText;

  ToolCallState({
    required this.toolName,
    required this.toolArgs,
    required this.status,
    this.steps = const <ToolStepState>[],
    this.currentTool,
    this.resultText,
  });
}

class ToolStepState {
  final String id;
  final String name;
  final String status; // 'in_progress', 'completed', 'error'
  final Map<String, dynamic> args;
  final List<String> outputs;

  ToolStepState({
    required this.id,
    required this.name,
    required this.status,
    Map<String, dynamic>? args,
    List<String>? outputs,
  })  : args = args ?? const <String, dynamic>{},
        outputs = outputs ?? const <String>[];

  factory ToolStepState.fromMap(Map<String, dynamic> data) {
    final outputs = <String>[];
    final rawOutputs = data['outputs'];
    if (rawOutputs is List) {
      for (final item in rawOutputs) {
        outputs.add(item.toString());
      }
    }

    return ToolStepState(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Step',
      status: data['status']?.toString() ?? 'completed',
      args: Map<String, dynamic>.from(data['args'] ?? {}),
      outputs: outputs,
    );
  }
}

// ------------------------------- Message Segment Model -----------------------
class MessageSegment {
  final String type; // 'text' or 'tool_call'
  final String? text;
  final String? toolId;

  MessageSegment({required this.type, this.text, this.toolId});
}

// ------------------------------- Message Parser ------------------------------
List<MessageSegment> parseMessageWithToolCalls(String message) {
  final segments = <MessageSegment>[];
  final regex = RegExp(r'<tool_call id="([^"]+)"></tool_call>');
  int lastIndex = 0;

  for (final match in regex.allMatches(message)) {
    if (match.start > lastIndex) {
      final textContent = message.substring(lastIndex, match.start);
      if (textContent.isNotEmpty) {
        segments.add(MessageSegment(type: 'text', text: textContent));
      }
    }

    segments.add(MessageSegment(type: 'tool_call', toolId: match.group(1)));
    lastIndex = match.end;
  }

  if (lastIndex < message.length) {
    final textContent = message.substring(lastIndex);
    if (textContent.isNotEmpty) {
      segments.add(MessageSegment(type: 'text', text: textContent));
    }
  }

  return segments;
}
