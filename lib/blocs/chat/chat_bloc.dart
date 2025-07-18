import 'package:flutter_bloc/flutter_bloc.dart';

import '/components/subunits/utilities.dart';
import '/services/gemini.dart';
import 'chat_event.dart';
import 'chat_state.dart';

final gemini = GeminiService();

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

      // 4. Send message to Gemini
      try {
        final response = await gemini.chat(event.message);
        chatHistory.add(ChatMessage(text: response, isMe: false));
      } catch (e) {
        chatHistory.add(ChatMessage(
          text:
              '\x1B[31mError: ${e.toString()}\x1B[0m', // ANSI escape code for red
          isMe: false,
        ));
      }

      // 5. Remove loading message
      chatHistory.removeWhere((m) => m.isLoading == true);

      // 6. Emit loaded state
      emit(ChatLoaded(chatHistory));
    });
  }
}
