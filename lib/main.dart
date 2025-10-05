import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/blocs/chat/chat_bloc.dart';
import '/pages/chat_interface.dart';
import '/services/api_service.dart';

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

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WindowListener {
  Process? _backendProcess;

  @override
  void initState() {
    super.initState();
    _startBackendServer();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }
  }

  Future<void> _startBackendServer() async {
    try {
      // Check if server is already running
      final healthStatus = await ApiService.healthCheck();
      if (healthStatus['status'] == 'healthy') {
        print('Backend server is already running on http://localhost:5000');
        return;
      }
    } catch (e) {
      print('Server not running, starting new instance...');
    }

    try {
      final workingDir = Directory.current.path;
      _backendProcess = await Process.start(
        'python',
        ['-u', 'backend/api.py'],
        workingDirectory: workingDir,
        runInShell: true,
      );

      _backendProcess!.stdout.transform(utf8.decoder).listen((data) {
        print('Backend: $data');
      });

      _backendProcess!.stderr.transform(utf8.decoder).listen((data) {
        print('Backend Error: $data');
      });

      print('Backend server started on http://localhost:5000');
      // Actively wait for readiness instead of fixed delay
      await ApiService.ensureBackendReady(timeout: const Duration(seconds: 60));
    } catch (e) {
      print('Failed to start backend server: $e');
    }
  }

  Future<void> _terminateBackend() async {
    if (Platform.isWindows) {
      final pid = _backendProcess?.pid;
      if (pid != null) {
        Process.runSync('taskkill', ['/PID', pid.toString(), '/T', '/F'],
            runInShell: true);
      } else {
        Process.runSync('taskkill', ['/F', '/IM', 'python.exe'],
            runInShell: true);
      }
    } else {
      _backendProcess?.kill();
    }
  }

  @override
  void dispose() {
    _terminateBackend();
    if (Platform.isWindows) {
      windowManager.removeListener(this);
      windowManager.setPreventClose(false);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await _terminateBackend();
      await windowManager.destroy();
    }
  }

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
