import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '/blocs/chat/chat_bloc.dart';
import '/blocs/chat/chat_event.dart';
import '/blocs/chat/chat_state.dart';

import '/components/app_bar.dart';
import '/components/input_bar.dart';
import '/components/massage_bubble.dart';
import '/components/sidebar.dart';
import '/theme.dart';
import '/services/api_service.dart';

class ChatInterface extends StatefulWidget {
  const ChatInterface({Key? key}) : super(key: key);

  @override
  State<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isDrawerOpen = false;
  final GlobalKey<State<Sidebar>> _sidebarKey = GlobalKey<State<Sidebar>>();
  List<String> _geminiModels = [];
  String? _activeGeminiModel;
  List<LocalModelInfo> _localModels = [];
  String? _activeLocalModel;
  LocalAgentStatus _localStatus = const LocalAgentStatus(running: false);
  bool _privacyMode = AppTheme.isPrivacyMode;
  bool _localBusy = false;
  late final VoidCallback _privacyModeListener;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 100), () {
      _scrollToBottom();
    });
    _loadGeminiModels();
    _loadLocalModels();

    _privacyModeListener = () {
      if (!mounted) return;
      setState(() {
        _privacyMode = AppTheme.isPrivacyMode;
      });
    };
    AppTheme.privacyModeNotifier.addListener(_privacyModeListener);
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
    if (_privacyMode && !_localStatus.running) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local model is not ready yet.')),
      );
      return;
    }
    if (_localBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please wait for the local model to be ready.')),
      );
      return;
    }
    final bloc = context.read<ChatBloc>();
    if (bloc.state.isStreaming) return;
    final useLocal = _privacyMode && _localStatus.running;
    bloc.add(SendMessage(
      prompt,
      useLocalAgent: useLocal,
      model: useLocal ? _activeLocalModel : _activeGeminiModel,
    ));
    controller.clear();
  }

  Future<void> _loadGeminiModels() async {
    try {
      final data = await ApiService.getGeminiModels();
      if (!mounted) return;
      setState(() {
        _geminiModels = List<String>.from(data['models'] ?? []);
        _activeGeminiModel = data['active'] as String?;
      });
    } catch (_) {
      if (!mounted) return;
      // Fallback to known defaults so UI is usable even if API fails
      setState(() {
        _geminiModels = const [
          'gemini-2.5-flash-lite',
          'gemini-2.5-flash',
          'gemini-2.5-pro',
        ];
        _activeGeminiModel = 'gemini-2.5-flash';
      });
    }
  }

  Future<void> _selectGeminiModel(String model) async {
    try {
      final newModel = await ApiService.setGeminiModel(model);
      if (!mounted) return;
      setState(() => _activeGeminiModel = newModel);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to switch model: $e')),
      );
    }
  }

  Future<void> _loadLocalModels() async {
    try {
      final result = await ApiService.listLocalModels();
      print(
          'Loaded local models: ${result.models.map((m) => m.name).toList()}');
      if (!mounted) return;
      final models = result.models;
      print('Local models: ${models.map((m) => m.name).toList()}');
      final status = result.status;
      print('Local agent status: running=${status.running}'
          ' model=${status.model}');
      setState(() {
        _localModels = models;
        _localStatus = status;
        _activeLocalModel =
            status.model ?? (models.isNotEmpty ? models.first.name : null);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load local models: $e')),
      );
    }
  }

  Future<bool> _startLocalModel(String model) async {
    if (_localBusy) return false;
    setState(() => _localBusy = true);
    try {
      await ApiService.startLocalModel(model);
      final result = await ApiService.listLocalModels();
      if (!mounted) return false;
      setState(() {
        _localModels = result.models;
        _localStatus = result.status;
        _activeLocalModel = result.status.model ??
            (result.models.isNotEmpty ? result.models.first.name : model);
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start local model: $e')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _localBusy = false);
      }
    }
  }

  Future<bool> _stopLocalModel() async {
    if (_localBusy) return false;
    setState(() => _localBusy = true);
    try {
      await ApiService.stopLocalModel();
      final status = await ApiService.getLocalAgentStatus();
      if (!mounted) return false;
      setState(() {
        _localStatus = status;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop local model: $e')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _localBusy = false);
      }
    }
  }

  Future<void> _togglePrivacyMode() async {
    final enable = !_privacyMode;
    if (enable) {
      AppTheme.setPrivacyMode(true);
      if (!mounted) return;
      setState(() {
        _privacyMode = true;
        _localStatus = const LocalAgentStatus(running: false);
      });
      if (_localModels.isEmpty) {
        unawaited(_loadLocalModels());
      }
    } else {
      if (_localStatus.running) {
        final stopped = await _stopLocalModel();
        if (!stopped) return;
      }
      if (mounted) {
        AppTheme.setPrivacyMode(false);
        setState(() {
          _privacyMode = false;
          _localStatus = const LocalAgentStatus(running: false);
        });
      }
    }
  }

  Future<void> _selectLocalModel(String model) async {
    setState(() {
      _activeLocalModel = model;
    });
    if (_privacyMode) {
      await _startLocalModel(model);
    }
  }

  Future<void> _terminateLocalManually() async {
    final stopped = await _stopLocalModel();
    if (stopped && mounted) {
      setState(() {
        _localStatus = const LocalAgentStatus(running: false);
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    _scrollController.dispose();
    AppTheme.privacyModeNotifier.removeListener(_privacyModeListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<ChatBloc>().state;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth < 600 ? screenWidth : 320.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.colors.backgroundColor,
        image: DecorationImage(
          image: AssetImage('assets/textures/flowers.png'),
          repeat: ImageRepeat.repeat,
          opacity: 0.08,
        ),
      ),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              if (_isDrawerOpen) {
                setState(() => _isDrawerOpen = false);
              }
            },
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1200),
                child: Scaffold(
                  extendBodyBehindAppBar: true,
                  appBar: PreferredSize(
                    preferredSize: Size.fromHeight(100),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      child: StylishAppBar(
                        title: _privacyMode ? 'Private Agent' : 'G Agent',
                        geminiModels: _geminiModels,
                        localModels: _localModels,
                        activeGeminiModel: _activeGeminiModel,
                        activeLocalModel: _activeLocalModel,
                        privacyMode: _privacyMode,
                        localRunning: _localStatus.running,
                        localBusy: _localBusy,
                        onSelectGeminiModel: _selectGeminiModel,
                        onSelectLocalModel: _selectLocalModel,
                        onTogglePrivacyMode: _togglePrivacyMode,
                        onTerminateLocal: _terminateLocalManually,
                      ),
                    ),
                  ),
                  body: Container(
                    color: AppTheme.colors.backgroundColor,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: BlocListener<ChatBloc, ChatState>(
                      listener: (context, state) {
                        if (state is ChatLoading || state is ChatLoaded) {
                          setState(() {
                            _scrollToBottom();
                          });
                        }
                        if (state is ChatLoaded) {
                          (_sidebarKey.currentState as dynamic)?.refresh();
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
                                padding: EdgeInsets.only(bottom: 300, top: 116),
                                itemCount: state.messages.length,
                                itemBuilder: (context, index) {
                                  final m = state.messages[index];
                                  return MessageBubble(
                                    message: m.text ?? '',
                                    isMe: m.isMe,
                                    isLoading: m.isLoading,
                                    toolCall: m.toolCall,
                                    toolCallStates: m.toolCallStates,
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
                                    onStop: () => context.read<ChatBloc>().add(
                                          StopStreaming(),
                                        ),
                                    isStreaming: state.isStreaming,
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
          ),
          // Animated drawer from left
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _isDrawerOpen ? 0 : -drawerWidth,
            top: 0,
            bottom: 0,
            width: drawerWidth,
            child: Material(
              elevation: 16,
              child: Sidebar(
                key: _sidebarKey,
                onNewChat: () {
                  context.read<ChatBloc>().add(NewChat());
                  setState(() => _isDrawerOpen = false);
                  (_sidebarKey.currentState as dynamic)?.refresh();
                },
                onSelectSession: (sessionId) {
                  context.read<ChatBloc>().add(LoadSession(sessionId));
                  setState(() => _isDrawerOpen = false);
                },
                onSettingsClosed: () {
                  // Reload local models when settings dialog closes
                  _loadLocalModels();
                },
              ),
            ),
          ),
          // Vertical segmented button - toggle and new chat
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _isDrawerOpen ? drawerWidth - 48 : 5,
            top: 6,
            child: Material(
              color: (screenWidth < 1200 || _isDrawerOpen)
                  ? Colors.transparent
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              elevation: (screenWidth < 1200 || _isDrawerOpen) ? 0 : 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _isDrawerOpen
                          ? Iconsax.sidebar_left
                          : Iconsax.sidebar_right,
                      size: 27,
                    ),
                    onPressed: () {
                      if (!_isDrawerOpen) {
                        (_sidebarKey.currentState as dynamic)?.refresh();
                      }
                      setState(() => _isDrawerOpen = !_isDrawerOpen);
                    },
                    tooltip: _isDrawerOpen ? 'Close Sidebar' : 'Open Sidebar',
                  ),
                  if (!_isDrawerOpen)
                    Container(
                      width: 32,
                      height: 1,
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  if (!_isDrawerOpen)
                    IconButton(
                      icon: Icon(
                        Iconsax.add_circle,
                        color: theme.colorScheme.primary,
                        size: 30,
                      ),
                      onPressed: () {
                        context.read<ChatBloc>().add(NewChat());
                        (_sidebarKey.currentState as dynamic)?.refresh();
                      },
                      tooltip: 'New Chat',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
