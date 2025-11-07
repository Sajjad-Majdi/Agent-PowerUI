import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';

import '/components/subunits/utilities.dart';
import '/services/api_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc() : super(ChatInitial()) {
    on<SendMessage>((event, emit) async {
      final chatHistory = state.messages;
      final sessionId = event.sessionId ?? state.sessionId;

      // 1. Add user message to the list
      chatHistory.add(ChatMessage(text: event.message, isMe: true));

      // 2. Add loading message to the list
      chatHistory.add(ChatMessage(isMe: false, isLoading: true));

      // 3. Emit loading state
      emit(ChatLoading(chatHistory, sessionId));

      // 4. Stream message from API
      try {
        String toolMarkers = '';
        Map<String, ToolCallState> toolCallStates = {};
        int toolCallCounter = 0;
        String? pendingToolCallId;
        int? toolMessageIndex;
        int? aiMessageIndex;

        await for (final chunk in ApiService.streamChat(
            message: event.message, sessionId: sessionId)) {
          
          // Handle MCP progress updates
          if (chunk['type'] == 'mcp_progress') {
            final dynamic content = chunk['content'];
            if (content is Map<String, dynamic> && pendingToolCallId != null) {
              final stepsData = content['steps'];
              if (stepsData is List && toolCallStates.containsKey(pendingToolCallId)) {
                final extracted = <ToolStepState>[];
                for (final entry in stepsData) {
                  if (entry is Map) {
                    extracted.add(
                      ToolStepState.fromMap(Map<String, dynamic>.from(entry)),
                    );
                  }
                }
                
                final previous = toolCallStates[pendingToolCallId]!;
                toolCallStates[pendingToolCallId] = ToolCallState(
                  toolName: previous.toolName,
                  toolArgs: previous.toolArgs,
                  status: 'in_progress',
                  steps: extracted,
                  currentTool: content['current_tool']?.toString(),
                );
                
                if (toolMessageIndex != null) {
                  chatHistory[toolMessageIndex].toolCallStates =
                      Map.from(toolCallStates);
                  emit(ChatLoading(chatHistory, sessionId));
                }
              }
            }
          }
          
          // Handle tool calls
          else if (chunk['type'] == 'tool_call') {
            final toolData = chunk['content'] as Map<String, dynamic>;
            final incomingName = toolData['name'] ?? 'Unknown Tool';
            final incomingArgs =
                Map<String, dynamic>.from(toolData['args'] ?? {});
            final incomingArgsKey = jsonEncode(incomingArgs);

            String? existingPendingId;
            toolCallStates.forEach((id, state) {
              if (state.status == 'in_progress' &&
                  state.toolName == incomingName &&
                  jsonEncode(state.toolArgs) == incomingArgsKey) {
                existingPendingId = id;
              }
            });

            if (existingPendingId != null) {
              // Duplicate tool_call for same tool; reuse existing id and do not add another placeholder
              pendingToolCallId = existingPendingId;
            } else {
              toolCallCounter++;
              final toolId = 'tool_$toolCallCounter';
              pendingToolCallId = toolId;

              toolCallStates[toolId] = ToolCallState(
                toolName: incomingName,
                toolArgs: incomingArgs,
                status: 'in_progress',
                steps: const <ToolStepState>[],
              );

              toolMarkers += '<tool_call id="$toolId"></tool_call>';
            }

            if (toolMessageIndex == null) {
              chatHistory.removeWhere((m) => m.isLoading == true);
              chatHistory.add(ChatMessage(
                text: toolMarkers,
                isMe: false,
                toolCallStates: Map.from(toolCallStates),
              ));
              toolMessageIndex = chatHistory.length - 1;
            } else {
              chatHistory[toolMessageIndex].text = toolMarkers;
              chatHistory[toolMessageIndex].toolCallStates =
                  Map.from(toolCallStates);
            }
            emit(ChatLoading(chatHistory, sessionId));
          }

          // Handle tool message (mark tool call as done, don't show message)
          else if (chunk['type'] == 'tool_message') {
            final dynamic content = chunk['content'];
            if (pendingToolCallId != null &&
                toolCallStates.containsKey(pendingToolCallId)) {
              final previous = toolCallStates[pendingToolCallId]!;

              List<ToolStepState> parsedSteps = previous.steps;
              String? currentTool;
              String? resultText;
              String statusValue = 'done';

              if (content is Map<String, dynamic>) {
                // Only parse steps if not already populated by mcp_progress
                if (previous.steps.isEmpty) {
                  final stepsData = content['steps'];
                  if (stepsData is List) {
                    final extracted = <ToolStepState>[];
                    for (final entry in stepsData) {
                      if (entry is Map) {
                        extracted.add(
                          ToolStepState.fromMap(
                              Map<String, dynamic>.from(entry)),
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

              toolCallStates[pendingToolCallId] = ToolCallState(
                toolName: previous.toolName,
                toolArgs: previous.toolArgs,
                status: statusValue,
                steps: parsedSteps,
                currentTool: currentTool,
                resultText: resultText,
              );

              if (toolMessageIndex != null) {
                chatHistory[toolMessageIndex].toolCallStates =
                    Map.from(toolCallStates);
                chatHistory[toolMessageIndex].text = toolMarkers;

                // After tool finishes, show a single global spinner for AI message generation
                chatHistory.removeWhere((m) => m.isLoading == true);
                chatHistory.add(ChatMessage(isMe: false, isLoading: true));

                emit(ChatLoading(chatHistory, sessionId));
              }
              pendingToolCallId = null;
            }
          }

          // Handle AI messages
          else if (chunk['type'] == 'ai_message') {
            final aiText = chunk['content'] ?? '';

            // Close the loading spinner and post AI message as a separate bubble
            chatHistory.removeWhere((m) => m.isLoading == true);

            if (aiMessageIndex == null) {
              chatHistory.add(ChatMessage(
                text: aiText,
                isMe: false,
              ));
              aiMessageIndex = chatHistory.length - 1;
            } else {
              chatHistory[aiMessageIndex].text = aiText;
            }

            // Reset tool aggregation so subsequent tools start a new box
            toolMarkers = '';
            toolCallStates = {};
            toolMessageIndex = null;

            emit(ChatLoading(chatHistory, sessionId));
          }

          // Handle completion
          else if (chunk['type'] == 'complete') {
            chatHistory.removeWhere((m) => m.isLoading == true);
            emit(ChatLoaded(chatHistory, sessionId));
          }

          // Handle errors
          else if (chunk['type'] == 'error') {
            chatHistory.removeWhere((m) => m.isLoading == true);
            chatHistory.add(ChatMessage(
              text: 'Error: ${chunk['content']}',
              isMe: false,
            ));
            emit(ChatLoaded(chatHistory, sessionId));
          }
        }
      } catch (e) {
        chatHistory.removeWhere((m) => m.isLoading == true);
        chatHistory.add(ChatMessage(
          text: 'Error: ${e.toString()}',
          isMe: false,
        ));
        emit(ChatLoaded(chatHistory, sessionId));
      }
    });

    on<LoadSession>((event, emit) async {
      emit(ChatLoading([], event.sessionId));
      try {
        final messages = await ApiService.loadSession(event.sessionId);
        emit(ChatLoaded(messages, event.sessionId));
      } catch (e) {
        emit(ChatError(
            [], event.sessionId, 'Failed to load session: ${e.toString()}'));
      }
    });

    on<NewChat>((event, emit) {
      final newSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      emit(ChatInitial(sessionId: newSessionId));
    });
  }
}
