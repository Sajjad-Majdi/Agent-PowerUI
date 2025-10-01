import 'package:flutter_bloc/flutter_bloc.dart';

import '/components/subunits/utilities.dart';
import '/services/api_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc() : super(ChatInitial()) {
    on<SendMessage>((event, emit) async {
      final chatHistory = state.messages;

      // 1. Add user message to the list
      chatHistory.add(ChatMessage(text: event.message, isMe: true));

      // 2. Add loading message to the list
      chatHistory.add(ChatMessage(isMe: false, isLoading: true));

      // 3. Emit loading state
      emit(ChatLoading(chatHistory));

      // 4. Stream message from API
      try {
        String fullResponse = '';
        await for (final chunk
            in ApiService.streamChat(message: event.message)) {
          if (chunk['type'] == 'chunk') {
            fullResponse += chunk['content'] ?? '';

            // Remove loading and previous AI messages, add updated message
            chatHistory.removeWhere((m) =>
                m.isLoading == true || (m.isMe == false && m.text != ''));
            chatHistory.add(ChatMessage(text: fullResponse, isMe: false));

            emit(ChatLoading(chatHistory));
          }
        }

        // Emit loaded state
        emit(ChatLoaded(chatHistory));
      } catch (e) {
        chatHistory.removeWhere((m) => m.isLoading == true);
        chatHistory.add(ChatMessage(
          text: '\x1B[31mError: ${e.toString()}\x1B[0m',
          isMe: false,
        ));
        emit(ChatLoaded(chatHistory));
      }
    });
  }
}
