import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/blocs/chat/chat_bloc.dart';
import '/pages/chat_interface.dart';

void main() async {
  // Ensure flutter bindings are initialized before doing anything else.
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    // Initialize the window manager.
    await windowManager.ensureInitialized();

    WindowOptions options = const WindowOptions(minimumSize: Size(540, 400));

    // Wait until the window is ready before showing it.
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ------------ Dark Theme ------------
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color.fromARGB(255, 15, 30, 46),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3A86FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF1B263B),
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(
            color: Colors.white.withAlpha(230),
            height: 1.5,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1B263B),
          hintStyle: TextStyle(color: Colors.white.withAlpha(150)),
        ),
        cardTheme: CardThemeData(color: const Color.fromARGB(255, 30, 50, 71)),
      ),
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => ChatBloc()),
        ],
        child: ChatInterface(),
      ),
    );
  }
}
