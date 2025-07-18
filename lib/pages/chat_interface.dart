import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/blocs/chat/chat_bloc.dart';
import '/blocs/chat/chat_event.dart';
import '/blocs/chat/chat_state.dart';

import '/components/app_bar.dart';
import '/components/input_bar.dart';
import '/components/massage_bubble.dart';

class ChatInterface extends StatefulWidget {
  const ChatInterface({Key? key}) : super(key: key);

  @override
  State<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // final gemini = GeminiService();

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 100), () {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _send() {
    final prompt = controller.text.trim();
    if (prompt.isEmpty) return;
    context.read<ChatBloc>().add(SendMessage(prompt));
    controller.clear();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<ChatBloc>().state;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
        ),
        image: DecorationImage(
          image: AssetImage('assets/textures/flowers.png'),
          repeat: ImageRepeat.repeat,
          opacity: 0.08,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 900),
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(80),
              child: StylishAppBar(
                title: 'Gemini',
                subtitle: 'Gemini 2.5 Flash Lite',
              ),
            ),
            body: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(color: theme.primaryColor, blurRadius: 20)
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: BlocListener<ChatBloc, ChatState>(
                listener: (context, state) {
                  if (state is ChatLoading || state is ChatLoaded) {
                    setState(() {
                      _scrollToBottom();
                    });
                  }
                  if (state is ChatError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${state.error}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context)
                            .copyWith(scrollbars: false),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(bottom: 300, top: 100),
                          itemCount: state.messages.length,
                          itemBuilder: (context, index) {
                            final m = state.messages[index];
                            return MessageBubble(
                              message: m.text ?? '',
                              isMe: m.isMe,
                              isLoading: m.isLoading,
                            );
                          },
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                          child: Container(
                            margin: EdgeInsets.fromLTRB(16, 3, 16, 16),
                            child: InputBar(
                              controller: controller,
                              onSend: _send,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
