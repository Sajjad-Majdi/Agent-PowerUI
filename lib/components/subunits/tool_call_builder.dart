import 'package:flutter/material.dart';
import 'dart:convert';

class ToolCallBuilder extends StatelessWidget {
  final String toolName;
  final Map<String, dynamic> toolArgs;

  const ToolCallBuilder({
    super.key,
    required this.toolName,
    required this.toolArgs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconData = _getToolIcon(toolName);
    final toolColor = _getToolColor(toolName);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: toolColor.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: toolColor.withAlpha(100), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconData, color: toolColor, size: 20),
              const SizedBox(width: 8),
              Text(
                _formatToolName(toolName),
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: toolColor,
                ),
              ),
            ],
          ),
          if (toolArgs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: toolArgs.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: 'FiraCode',
                          fontSize: 13,
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
        ],
      ),
    );
  }

  IconData _getToolIcon(String toolName) {
    final lowerName = toolName.toLowerCase();
    if (lowerName.contains('search') || lowerName.contains('web')) {
      return Icons.search_rounded;
    } else if (lowerName.contains('memory') || lowerName.contains('update')) {
      return Icons.save_rounded;
    } else if (lowerName.contains('read') || lowerName.contains('file')) {
      return Icons.description_rounded;
    } else if (lowerName.contains('write') || lowerName.contains('create')) {
      return Icons.edit_rounded;
    } else if (lowerName.contains('calculate') || lowerName.contains('math')) {
      return Icons.calculate_rounded;
    } else {
      return Icons.build_rounded;
    }
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

