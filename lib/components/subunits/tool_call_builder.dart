import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:convert';

import '/components/subunits/utilities.dart';
import '/components/subunits/think_tool_builder.dart';

class ToolCallBuilder extends StatelessWidget {
  final String toolName;
  final Map<String, dynamic> toolArgs;
  final String
      status; // 'initializing', 'in_progress', 'done', 'error', 'cancelled'
  final List<ToolStepState> steps;
  final String? currentTool;
  final String? resultText;

  const ToolCallBuilder({
    super.key,
    required this.toolName,
    required this.toolArgs,
    this.status = 'done',
    this.steps = const <ToolStepState>[],
    this.currentTool,
    this.resultText,
  });

  bool get _isMcpTool => toolName.toLowerCase().startsWith('mcp');

  @override
  Widget build(BuildContext context) {
    // Use specialized builder for think tool
    if (toolName.toLowerCase() == 'think_tool') {
      return ThinkToolBuilder(
        toolArgs: toolArgs,
        status: status,
      );
    }

    final theme = Theme.of(context);
    final toolColor = _getToolColor(toolName);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: toolColor.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: toolColor.withAlpha(100), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusIcon(toolColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatToolName(toolName),
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: toolColor,
                  ),
                ),
              ),
            ],
          ),

          // آرگومان‌های ابزار اصلی
          if (toolArgs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withAlpha(15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: toolArgs.entries.map((entry) {
                  return RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${entry.key}: ',
                          style: TextStyle(
                            fontFamily: 'FiraCode',
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: _formatArgValue(entry.value),
                          style: TextStyle(
                            fontFamily: 'FiraCode',
                            fontSize: 11,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  );
                }).toList(),
              ),
            ),
          ],

          // بخش وضعیت (بدون لیست طولانی)
          if (_isMcpTool) ...[
            const SizedBox(height: 8),
            _buildMcpAgentSimpleStatus(theme, toolColor),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(Color toolColor) {
    // For MCP agents we don't show the build/progress indicator
    // on the top row — the MCP UI already shows a circular
    // indicator on the agent button. A small icon before the
    // agent/subagent name is sufficient.
    if (_isMcpTool) {
      return Icon(Iconsax.hierarchy, color: toolColor, size: 16);
    }

    if (status == 'initializing' || status == 'in_progress') {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: toolColor,
        ),
      );
    } else if (status == 'error' || status == 'cancelled') {
      // آیکون مخصوص ارور (قرمز)
      return const Icon(Icons.error_outline, color: Colors.red, size: 16);
    } else {
      return const Icon(Icons.check_circle, color: Colors.green, size: 16);
    }
  }

  Widget _buildMcpAgentSimpleStatus(ThemeData theme, Color toolColor) {
    String message = '';
    Color messageColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    FontStyle style = FontStyle.normal;
    // small leading indicator/icon for statuses
    Widget leadingIndicator = const SizedBox.shrink();

    switch (status) {
      case 'initializing':
        message = 'Initializing agent ...';
        style = FontStyle.italic;
        messageColor = Colors.grey.shade300;

        leadingIndicator = SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.grey,
          ),
        );

        break;
      case 'in_progress':
        final tool = currentTool ?? 'Processing...';
        message = '${_formatToolName(tool)}';
        style = FontStyle.italic;
        messageColor = Colors.grey.shade300;
        leadingIndicator = SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: Colors.grey,
          ),
        );
        break;
      case 'cancelled':
        message = 'Process Canceled';
        messageColor = Colors.red;
        leadingIndicator =
            const Icon(Icons.cancel_outlined, color: Colors.red, size: 14);
        break;
      case 'error':
        message = resultText != null
            ? 'Process Failed: $resultText'
            : 'Process Failed';
        messageColor = Colors.red;
        leadingIndicator =
            const Icon(Icons.error_outline, color: Colors.red, size: 14);
        break;
      case 'done':
        message = "Agent is done.";
        messageColor = Colors.green;
        leadingIndicator =
            const Icon(Icons.check_circle, color: Colors.blueAccent, size: 14);
        break;
      default:
        message = '';
    }

    if (message.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        // leading tiny indicator / icon
        leadingIndicator,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontStyle: style,
              color: messageColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getToolColor(String toolName) {
    final lowerName = toolName.toLowerCase();
    if (lowerName.contains('file_explorer') || lowerName.contains('explorer')) {
      return Colors.indigo;
    } else if (lowerName.contains('search') || lowerName.contains('web')) {
      return Colors.blue;
    } else if (lowerName.contains('memory') || lowerName.contains('update')) {
      return Colors.purple;
    } else if (lowerName.contains('read') || lowerName.contains('file')) {
      return Colors.orange;
    } else if (lowerName.contains('write') || lowerName.contains('create')) {
      return Colors.green;
    } else if (lowerName.contains('calculate') || lowerName.contains('math')) {
      return Colors.teal;
    } else {
      return Colors.grey;
    }
  }

  String _formatToolName(String name) {
    return name
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');
  }

  String _formatArgValue(dynamic value) {
    if (value is String) {
      return value.length > 100 ? '${value.substring(0, 100)}...' : value;
    } else if (value is Map || value is List) {
      final jsonStr = jsonEncode(value);
      return jsonStr.length > 100 ? '${jsonStr.substring(0, 100)}...' : jsonStr;
    } else {
      return value.toString();
    }
  }
}
