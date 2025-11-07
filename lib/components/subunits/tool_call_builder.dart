import 'package:flutter/material.dart';
import 'dart:convert';

import '/components/subunits/utilities.dart';

class ToolCallBuilder extends StatelessWidget {
  final String toolName;
  final Map<String, dynamic> toolArgs;
  final String status; // 'in_progress' or 'done'
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

  @override
  Widget build(BuildContext context) {
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
              if (status == 'in_progress')
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: toolColor,
                  ),
                )
              else
                Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Text(
                _formatToolName(toolName),
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: toolColor,
                ),
              ),
            ],
          ),
          if (toolArgs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: toolArgs.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: 'FiraCode',
                          fontSize: 11,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                        children: [
                          TextSpan(
                            text: '${entry.key}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          TextSpan(
                            text: _formatArgValue(entry.value),
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withAlpha(200),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps.map((step) {
                final isActive = step.status == 'in_progress';
                final isError = step.status == 'error';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: isActive
                            ? CircularProgressIndicator(
                                strokeWidth: 2,
                                color: toolColor,
                              )
                            : Icon(
                                isError
                                    ? Icons.error_outline
                                    : Icons.check_circle,
                                color: isError ? Colors.red : Colors.green,
                                size: 14,
                              ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _formatToolName(step.name),
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.w600,
                            fontSize: 12,
                            color: isError
                                ? Colors.red
                                : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else if (status == 'in_progress') ...[
            const SizedBox(height: 8),
            Text(
              'MCP agent is running...',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getToolColor(String toolName) {
    final lowerName = toolName.toLowerCase();
    if (lowerName.contains('search') || lowerName.contains('web')) {
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
