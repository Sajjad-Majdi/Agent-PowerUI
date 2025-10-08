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
  final String status; // 'in_progress' or 'done'

  ToolCallState({
    required this.toolName,
    required this.toolArgs,
    required this.status,
  });
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
