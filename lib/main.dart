import 'dart:io';
import 'package:flutter/material.dart';
import 'package:test_flutter/pages/chat_interface.dart';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';

// import 'pages/animation.dart';

void main() async {
  // Ensure flutter bindings are initialized before doing anything else.
  WidgetsFlutterBinding.ensureInitialized();
  await GoogleFonts.pendingFonts();

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
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          // light palette
          seedColor: const Color(0xFF7A5CF3),
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
        ),
      ),

      // ------------ Dark Theme ------------
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3A86FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF1B263B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B263B),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.black,
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(
            color: Colors.white.withAlpha(230),
            height: 1.5,
          ),
        ).apply(
          bodyColor: Colors.white.withAlpha(230),
          displayColor: Colors.white.withAlpha(230),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1B263B),
          hintStyle: TextStyle(color: Colors.white.withAlpha(150)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24.0),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(color: const Color.fromARGB(255, 30, 50, 71)),
      ),
      home: ChatInterface(),
    );
  }
}
