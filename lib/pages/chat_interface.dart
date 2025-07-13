import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '/components/app_bar.dart';
import '/components/input_bar.dart';
import '/components/massage_bubble.dart';
import '/services/gemini.dart';
import '../services/modules.dart';

final sample1 = r'''
# 🥳 Welcome to the **Ultimate Markdown Cheat Sheet**!

## 1. Code

**CODE BLOCK:**
```python
# Example Python function
def add(a, b):
    return a + b
```

**INLINE CODE:**
Use `final myVar = 42;` to declare an immutable variable.


## 2. Emphasis

- *Italic* text  
- **Bold** text  
- ***Bold & italic*** text  
- ~~Strikethrough~~  

## 3. Math

**INLINE MATH:**
Euler’s identity is amazing: 
$$e^{i\pi} + 1 = 0$$

**BLOCK MATH:**
The derivative of $f(x)=x^2$  is $f'(x)=2x$.


## 4. Links & Images

- Link to [Flutter’s website](https://flutter.dev)  

![Cute Cat GIF](https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif)  


''';

class ChatMessage {
  String? text;
  final bool isMe;
  bool isLoading;
  ChatMessage({this.text, required this.isMe, this.isLoading = false});
}

class ChatInterface extends StatefulWidget {
  const ChatInterface({Key? key}) : super(key: key);

  @override
  State<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final gemini = GeminiService();
  final List<ChatMessage> messages = [];

  @override
  void initState() {
    super.initState();
    // Scroll to bottom when the widget is first built
    SchedulerBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final prompt = controller.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      controller.clear();
      messages.add(ChatMessage(text: prompt, isMe: true));
      messages.add(ChatMessage(isMe: false, isLoading: true));
    });

    // Scroll to bottom after adding messages
    SchedulerBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final response = await sendPrompt(prompt);
    // final response = await gemini.chat(prompt);

    setState(() {
      final idx = messages.lastIndexWhere((m) => m.isLoading);
      if (idx != -1) {
        messages[idx]
          ..text = response
          ..isLoading = false;
      }
    });

    // Scroll to bottom after receiving response
    SchedulerBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.only(bottom: 300, top: 100),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final m = messages[index];
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
    );
  }
}
