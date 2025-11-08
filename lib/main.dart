import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/blocs/chat/chat_bloc.dart';
import '/pages/chat_interface.dart';
import '/services/api_service.dart';
import '/theme.dart';

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
      // Server not running, proceed to start it
    }

    try {
      final workingDir = Directory.current.path;
      _backendProcess = await Process.start(
        'python',
        ['-u', 'backend/api.py'],
        workingDirectory: workingDir,
        runInShell: true,
      );

      _backendProcess!.stderr.transform(utf8.decoder).listen((data) {
        print('Backend: $data');
      });

      await ApiService.ensureBackendReady(timeout: const Duration(seconds: 60));
      print('Backend server started on http://localhost:5000');
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
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await _terminateBackend();
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppTheme.privacyModeNotifier,
      builder: (context, isPrivacy, _) {
        final palette = AppTheme.colors;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: palette.backgroundColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: palette.primaryColor,
              brightness: Brightness.dark,
              surface: palette.messageBubbleColor,
            ),
          ),
          home: MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => ChatBloc()),
            ],
            child: ChatInterface(),
          ),
        );
      },
    );
  }
}
