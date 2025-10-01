import 'package:flutter/foundation.dart';
import '/components/subunits/utilities.dart';

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

@immutable
abstract class ChatState {
  final List<ChatMessage> messages;
  const ChatState(this.messages);
}

class ChatInitial extends ChatState {
  ChatInitial() : super([]);
}

class ChatLoading extends ChatState {
  const ChatLoading(super.messages);
}

class ChatLoaded extends ChatState {
  const ChatLoaded(super.messages);
}

class ChatError extends ChatState {
  final String error;
  const ChatError(super.messages, this.error);
}
