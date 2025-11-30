import 'package:flutter/material.dart';
import 'dart:convert';

class ThinkToolBuilder extends StatefulWidget {
  final Map<String, dynamic> toolArgs;
  final String status;

  const ThinkToolBuilder({
    super.key,
    required this.toolArgs,
    this.status = 'done',
  });

  @override
  State<ThinkToolBuilder> createState() => _ThinkToolBuilderState();
}

class _ThinkToolBuilderState extends State<ThinkToolBuilder>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thoughtColor = Colors.deepPurple;
    final thoughtText =
        widget.toolArgs['thought'] ?? widget.toolArgs['thoughts'] ?? '';
    final isThinking =
        widget.status == 'in_progress' || widget.status == 'initializing';

    // Clean up thought text
    final displayText = _formatThought(thoughtText);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: thoughtColor.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: thoughtColor.withAlpha(80), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12), bottom: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Animated icon when thinking
                  isThinking
                      ? FadeTransition(
                          opacity:
                              Tween(begin: 0.5, end: 1.0).animate(_controller),
                          child: Icon(Icons.psychology,
                              color: thoughtColor, size: 20),
                        )
                      : Icon(Icons.psychology_outlined,
                          color: thoughtColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isThinking ? 'Thinking...' : 'Thought Process',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: thoughtColor,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: thoughtColor.withAlpha(150),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: thoughtColor.withAlpha(30),
                    width: 1,
                  ),
                ),
                child: displayText.isEmpty && isThinking
                    ? Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: thoughtColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Generating thoughts...',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        displayText,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          height: 1.5,
                          color:
                              theme.textTheme.bodyMedium?.color?.withAlpha(220),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatThought(dynamic thought) {
    if (thought == null) return '';
    if (thought is String) {
      return thought.trim();
    } else if (thought is Map || thought is List) {
      return jsonEncode(thought);
    } else {
      return thought.toString();
    }
  }
}
