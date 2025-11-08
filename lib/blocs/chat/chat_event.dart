import 'package:flutter/foundation.dart';

@immutable
abstract class ChatEvent {}

class SendMessage extends ChatEvent {
  final String message;
  final String? sessionId;
  final bool useLocalAgent;
  final String? model;

  SendMessage(
    this.message, {
    this.sessionId,
    this.useLocalAgent = false,
    this.model,
  });
}

class LoadSession extends ChatEvent {
  final String sessionId;

  LoadSession(this.sessionId);
}

class StopStreaming extends ChatEvent {}

class NewChat extends ChatEvent {}
