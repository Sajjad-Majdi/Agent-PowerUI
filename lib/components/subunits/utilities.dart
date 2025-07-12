import 'package:characters/characters.dart';
import 'package:intl/intl.dart';

bool isRTL(String text) {
  for (final ch in text.characters) {
    if (ch.trim().isEmpty) continue;
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(ch)) continue;

    return Bidi.hasAnyRtl(ch);
  }
  return false;
}
