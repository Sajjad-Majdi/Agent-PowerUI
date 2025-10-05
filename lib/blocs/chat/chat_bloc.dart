import 'package:flutter_bloc/flutter_bloc.dart';

import '/components/subunits/utilities.dart';
import '/services/api_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc() : super(ChatInitial()) {
    on<SendMessage>((event, emit) async {
      final chatHistory = state.messages;
      final sessionId = event.sessionId ?? state.sessionId;

      // 1. Add user message to the list
      chatHistory.add(ChatMessage(text: event.message, isMe: true));

      // 2. Add loading message to the list
      chatHistory.add(ChatMessage(isMe: false, isLoading: true));

      // 3. Emit loading state
      emit(ChatLoading(chatHistory, sessionId));

      // 4. Stream message from API
      try {
        String fullResponse = '';
        await for (final chunk in ApiService.streamChat(
            message: event.message, sessionId: sessionId)) {
          // Handle tool calls
          if (chunk['type'] == 'tool_call') {
            chatHistory.removeWhere((m) => m.isLoading == true);
            chatHistory.add(ChatMessage(
              isMe: false,
              toolCall: chunk['content'],
            ));
            chatHistory.add(ChatMessage(isMe: false, isLoading: true));
            emit(ChatLoading(chatHistory, sessionId));
          }

          // Handle AI messages
          else if (chunk['type'] == 'ai_message') {
            fullResponse = chunk['content'] ?? '';
            chatHistory.removeWhere((m) => m.isLoading == true);
            chatHistory.add(ChatMessage(text: fullResponse, isMe: false));
            emit(ChatLoading(chatHistory, sessionId));
          }

          // Handle completion
          else if (chunk['type'] == 'complete') {
            chatHistory.removeWhere((m) => m.isLoading == true);
            emit(ChatLoaded(chatHistory, sessionId));
          }

          // Handle errors
          else if (chunk['type'] == 'error') {
            chatHistory.removeWhere((m) => m.isLoading == true);
            chatHistory.add(ChatMessage(
              text: 'Error: ${chunk['content']}',
              isMe: false,
            ));
            emit(ChatLoaded(chatHistory, sessionId));
          }
        }
      } catch (e) {
        chatHistory.removeWhere((m) => m.isLoading == true);
        chatHistory.add(ChatMessage(
          text: 'Error: ${e.toString()}',
          isMe: false,
        ));
        emit(ChatLoaded(chatHistory, sessionId));
      }
    });

    on<LoadSession>((event, emit) async {
      emit(ChatLoading([], event.sessionId));
      try {
        final messages = await ApiService.loadSession(event.sessionId);
        emit(ChatLoaded(messages, event.sessionId));
      } catch (e) {
        emit(ChatError(
            [], event.sessionId, 'Failed to load session: ${e.toString()}'));
      }
    });

    on<NewChat>((event, emit) {
      final newSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      emit(ChatInitial(sessionId: newSessionId));
    });
  }
}
