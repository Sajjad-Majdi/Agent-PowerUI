import 'package:flutter/foundation.dart';

@immutable
abstract class ChatEvent {}

class SendMessage extends ChatEvent {
  final String message;
  final String? sessionId;

  SendMessage(this.message, {this.sessionId});
}

class LoadSession extends ChatEvent {
  final String sessionId;

  LoadSession(this.sessionId);
}

class NewChat extends ChatEvent {}
