import 'package:flutter/foundation.dart';

@immutable
abstract class ChatEvent {}

class SendMessage extends ChatEvent {
  final String message;

  SendMessage(this.message);
}
