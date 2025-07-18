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
  ChatMessage({this.text, required this.isMe, this.isLoading = false});
}
