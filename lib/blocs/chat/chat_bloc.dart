import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '/components/subunits/utilities.dart';
import '/services/api_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc() : super(ChatInitial()) {
    on<SendMessage>(_onSendMessage);
    on<StopStreaming>(_onStopStreaming);
    on<_ChatStreamChunk>(_onStreamChunk);
    on<_ChatStreamError>(_onStreamError);
    on<_ChatStreamComplete>(_onStreamComplete);
    on<LoadSession>(_onLoadSession);
    on<NewChat>(_onNewChat);
  }

  StreamSubscription<Map<String, dynamic>>? _streamSubscription;
  List<ChatMessage> _activeMessages = [];
  bool _isStreaming = false;
  bool _userCancelled = false;

  String _toolMarkers = '';
  Map<String, ToolCallState> _toolCallStates = {};
  int _toolCallCounter = 0;
  String? _pendingToolCallId;
  int? _toolMessageIndex;
  int? _aiMessageIndex;

  void _resetStreamingAggregates() {
    _toolMarkers = '';
    _toolCallStates = {};
    _toolCallCounter = 0;
    _pendingToolCallId = null;
    _toolMessageIndex = null;
    _aiMessageIndex = null;
  }

  Future<void> _cancelSubscription() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _isStreaming = false;
  }

  Future<void> _onSendMessage(
      SendMessage event, Emitter<ChatState> emit) async {
    final trimmed = event.message.trim();
    if (trimmed.isEmpty) return;

    final sessionId = event.sessionId ?? state.sessionId;
    final existingMessages = List<ChatMessage>.from(state.messages);
    _activeMessages = existingMessages;

    _activeMessages.add(ChatMessage(text: trimmed, isMe: true));
    _activeMessages.add(ChatMessage(isMe: false, isLoading: true));

    _resetStreamingAggregates();
    _isStreaming = true;
    _userCancelled = false;

    emit(ChatLoading(_activeMessages, sessionId));

    try {
      _streamSubscription = ApiService.streamChat(
        message: trimmed,
        sessionId: sessionId,
      ).listen(
        (chunk) => add(_ChatStreamChunk(chunk)),
        onError: (error, stackTrace) => add(_ChatStreamError(error.toString())),
        onDone: () => add(_ChatStreamComplete()),
      );
    } catch (e) {
      await _cancelSubscription();
      _activeMessages.removeWhere((m) => m.isLoading == true);
      _activeMessages.add(ChatMessage(
        text: 'Error: ${e.toString()}',
        isMe: false,
      ));
      emit(ChatLoaded(_activeMessages, sessionId));
    }
  }

  Future<void> _onStopStreaming(
      StopStreaming event, Emitter<ChatState> emit) async {
    if (!_isStreaming || _userCancelled) return;
    _userCancelled = true;

    // Mark any in-progress tool calls as cancelled immediately
    _toolCallStates.forEach((id, state) {
      if (state.status == 'in_progress') {
        _toolCallStates[id] = ToolCallState(
          toolName: state.toolName,
          toolArgs: state.toolArgs,
          status: 'cancelled',
          steps: state.steps,
          currentTool: state.currentTool,
          resultText: 'Cancelled',
        );
      }
    });
    if (_toolMessageIndex != null) {
      _activeMessages[_toolMessageIndex!].toolCallStates =
          Map.from(_toolCallStates);
      emit(ChatLoading(_activeMessages, state.sessionId));
    }

    try {
      await ApiService.cancelChat(sessionId: state.sessionId);
    } catch (_) {
      // ignore cancellation errors to avoid blocking UI
    }

    await _cancelSubscription();
    _finishStreaming(
      emit,
      state.sessionId,
      messageText: 'Cancelled by user',
      status: ChatLoadedStatus.cancelled,
    );
  }

  Future<void> _onStreamChunk(
      _ChatStreamChunk event, Emitter<ChatState> emit) async {
    if (!_isStreaming) return;

    final chunk = event.chunk;
    final type = chunk['type'];
    final sessionId = state.sessionId;

    if (type == 'mcp_progress') {
      final dynamic content = chunk['content'];
      if (content is Map<String, dynamic> && _pendingToolCallId != null) {
        final stepsData = content['steps'];
        if (stepsData is List &&
            _toolCallStates.containsKey(_pendingToolCallId)) {
          final extracted = <ToolStepState>[];
          for (final entry in stepsData) {
            if (entry is Map) {
              extracted.add(
                ToolStepState.fromMap(Map<String, dynamic>.from(entry)),
              );
            }
          }

          final previous = _toolCallStates[_pendingToolCallId]!;
          _toolCallStates[_pendingToolCallId!] = ToolCallState(
            toolName: previous.toolName,
            toolArgs: previous.toolArgs,
            status: 'in_progress',
            steps: extracted,
            currentTool: content['current_tool']?.toString(),
          );

          if (_toolMessageIndex != null) {
            _activeMessages[_toolMessageIndex!].toolCallStates =
                Map.from(_toolCallStates);
            emit(ChatLoading(_activeMessages, sessionId));
          }
        }
      }
    } else if (type == 'tool_call') {
      final toolData = chunk['content'] as Map<String, dynamic>;
      final incomingName = toolData['name'] ?? 'Unknown Tool';
      final incomingArgs = Map<String, dynamic>.from(toolData['args'] ?? {});
      final incomingArgsKey = jsonEncode(incomingArgs);

      String? existingPendingId;
      _toolCallStates.forEach((id, state) {
        if (state.status == 'in_progress' &&
            state.toolName == incomingName &&
            jsonEncode(state.toolArgs) == incomingArgsKey) {
          existingPendingId = id;
        }
      });

      if (existingPendingId != null) {
        _pendingToolCallId = existingPendingId;
      } else {
        _toolCallCounter++;
        final toolId = 'tool_$_toolCallCounter';
        _pendingToolCallId = toolId;

        _toolCallStates[toolId] = ToolCallState(
          toolName: incomingName,
          toolArgs: incomingArgs,
          status: 'in_progress',
          steps: const <ToolStepState>[],
        );

        _toolMarkers += '<tool_call id="$toolId"></tool_call>';
      }

      if (_toolMessageIndex == null) {
        _activeMessages.removeWhere((m) => m.isLoading == true);
        _activeMessages.add(
          ChatMessage(
            text: _toolMarkers,
            isMe: false,
            toolCallStates: Map.from(_toolCallStates),
          ),
        );
        _toolMessageIndex = _activeMessages.length - 1;
      } else {
        _activeMessages[_toolMessageIndex!].text = _toolMarkers;
        _activeMessages[_toolMessageIndex!].toolCallStates =
            Map.from(_toolCallStates);
      }
      emit(ChatLoading(_activeMessages, sessionId));
    } else if (type == 'tool_message') {
      final dynamic content = chunk['content'];
      if (_pendingToolCallId != null &&
          _toolCallStates.containsKey(_pendingToolCallId)) {
        final previous = _toolCallStates[_pendingToolCallId]!;

        List<ToolStepState> parsedSteps = previous.steps;
        String? currentTool;
        String? resultText;
        String statusValue = 'done';

        if (content is Map<String, dynamic>) {
          if (previous.steps.isEmpty) {
            final stepsData = content['steps'];
            if (stepsData is List) {
              final extracted = <ToolStepState>[];
              for (final entry in stepsData) {
                if (entry is Map) {
                  extracted.add(
                    ToolStepState.fromMap(Map<String, dynamic>.from(entry)),
                  );
                }
              }
              if (extracted.isNotEmpty) {
                parsedSteps = extracted;
              }
            }
          } else {
            parsedSteps = previous.steps;
          }

          final current = content['current_tool'];
          if (current != null) {
            currentTool = current.toString();
          }

          final error = content['error'];
          if (error != null) {
            statusValue = 'error';
            if (error.toString().isNotEmpty) {
              resultText = 'Error: ${error.toString()}';
            }
          }
        }

        _toolCallStates[_pendingToolCallId!] = ToolCallState(
          toolName: previous.toolName,
          toolArgs: previous.toolArgs,
          status: statusValue,
          steps: parsedSteps,
          currentTool: currentTool,
          resultText: resultText,
        );

        if (_toolMessageIndex != null) {
          _activeMessages[_toolMessageIndex!].toolCallStates =
              Map.from(_toolCallStates);
          _activeMessages[_toolMessageIndex!].text = _toolMarkers;
          _activeMessages.removeWhere((m) => m.isLoading == true);
          _activeMessages.add(ChatMessage(isMe: false, isLoading: true));
          emit(ChatLoading(_activeMessages, sessionId));
        }
        _pendingToolCallId = null;
      }
    } else if (type == 'ai_message') {
      final aiText = chunk['content'] ?? '';
      _activeMessages.removeWhere((m) => m.isLoading == true);

      if (_aiMessageIndex == null) {
        _activeMessages.add(ChatMessage(
          text: aiText,
          isMe: false,
        ));
        _aiMessageIndex = _activeMessages.length - 1;
      } else {
        _activeMessages[_aiMessageIndex!].text = aiText;
      }

      _toolMarkers = '';
      _toolCallStates = {};
      _toolMessageIndex = null;

      emit(ChatLoading(_activeMessages, sessionId));
    } else if (type == 'error') {
      await _cancelSubscription();
      _finishStreaming(
        emit,
        sessionId,
        messageText: 'Error: ${chunk['content']}',
        status: ChatLoadedStatus.error,
      );
    } else if (type == 'cancelled') {
      // Mark any in-progress tool calls as cancelled
      _toolCallStates.forEach((id, state) {
        if (state.status == 'in_progress') {
          _toolCallStates[id] = ToolCallState(
            toolName: state.toolName,
            toolArgs: state.toolArgs,
            status: 'cancelled',
            steps: state.steps,
            currentTool: state.currentTool,
            resultText: 'Cancelled',
          );
        }
      });
      if (_toolMessageIndex != null) {
        _activeMessages[_toolMessageIndex!].toolCallStates =
            Map.from(_toolCallStates);
      }

      await _cancelSubscription();
      _finishStreaming(
        emit,
        sessionId,
        messageText: _userCancelled ? 'Cancelled by user' : 'Cancelled',
        status: ChatLoadedStatus.cancelled,
      );
    } else if (type == 'complete') {
      await _cancelSubscription();
      _finishStreaming(emit, sessionId);
    }
  }

  Future<void> _onStreamError(
      _ChatStreamError event, Emitter<ChatState> emit) async {
    if (!_isStreaming) return;
    await _cancelSubscription();
    _finishStreaming(
      emit,
      state.sessionId,
      messageText: 'Error: ${event.error}',
      status: ChatLoadedStatus.error,
    );
  }

  Future<void> _onStreamComplete(
      _ChatStreamComplete event, Emitter<ChatState> emit) async {
    if (_isStreaming) {
      await _cancelSubscription();
      _finishStreaming(emit, state.sessionId);
    }
  }

  Future<void> _onLoadSession(
      LoadSession event, Emitter<ChatState> emit) async {
    await _cancelSubscription();
    emit(ChatLoading([], event.sessionId));
    try {
      final messages = await ApiService.loadSession(event.sessionId);
      _activeMessages = List<ChatMessage>.from(messages);
      emit(ChatLoaded(_activeMessages, event.sessionId));
    } catch (e) {
      emit(ChatError(
          [], event.sessionId, 'Failed to load session: ${e.toString()}'));
    }
  }

  Future<void> _onNewChat(NewChat event, Emitter<ChatState> emit) async {
    await _cancelSubscription();
    _activeMessages = [];
    final newSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    emit(ChatInitial(sessionId: newSessionId));
  }

  void _finishStreaming(
    Emitter<ChatState> emit,
    String sessionId, {
    String? messageText,
    ChatLoadedStatus status = ChatLoadedStatus.completed,
  }) {
    _isStreaming = false;

    _activeMessages.removeWhere((m) => m.isLoading == true);
    if (messageText != null &&
        messageText.isNotEmpty &&
        status != ChatLoadedStatus.cancelled) {
      _activeMessages.add(ChatMessage(text: messageText, isMe: false));
    }

    _resetStreamingAggregates();

    if (status == ChatLoadedStatus.error) {
      emit(ChatError(_activeMessages, sessionId, messageText ?? 'Error'));
    } else {
      emit(ChatLoaded(_activeMessages, sessionId,
          isCancelled: status == ChatLoadedStatus.cancelled));
    }
  }

  @override
  Future<void> close() async {
    await _cancelSubscription();
    return super.close();
  }
}

class _ChatStreamChunk extends ChatEvent {
  final Map<String, dynamic> chunk;
  _ChatStreamChunk(this.chunk);
}

class _ChatStreamError extends ChatEvent {
  final String error;
  _ChatStreamError(this.error);
}

class _ChatStreamComplete extends ChatEvent {}

enum ChatLoadedStatus { completed, cancelled, error }
