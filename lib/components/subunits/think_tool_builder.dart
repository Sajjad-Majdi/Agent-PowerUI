import 'package:flutter/material.dart';
import 'dart:convert';

import '/theme.dart';

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
      duration: const Duration(milliseconds: 1200),
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
    final primaryColor = AppTheme.currentMainColor;
    final thoughtText =
        widget.toolArgs['thought'] ?? widget.toolArgs['thoughts'] ?? '';
    final isThinking =
        widget.status == 'in_progress' || widget.status == 'initializing';

    // Clean up thought text
    final displayText = _formatThought(thoughtText);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(_isExpanded ? 12 : 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: _isExpanded ? 10 : 8,
            ),
            decoration: BoxDecoration(
              color: primaryColor.withAlpha(18),
              borderRadius: BorderRadius.circular(_isExpanded ? 12 : 20),
              border: Border.all(
                color: primaryColor.withAlpha(50),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Row(
                  mainAxisSize:
                      _isExpanded ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    // Animated thinking icon
                    isThinking
                        ? FadeTransition(
                            opacity: Tween(begin: 0.4, end: 1.0)
                                .animate(_controller),
                            child: Icon(Icons.psychology,
                                color: primaryColor, size: 16),
                          )
                        : Icon(Icons.lightbulb_outline,
                            color: primaryColor, size: 16),
                    const SizedBox(width: 6),
                    if (_isExpanded)
                      Expanded(
                        child: Text(
                          isThinking ? 'Thinking...' : 'Thought Process',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: primaryColor,
                          ),
                        ),
                      )
                    else
                      Text(
                        isThinking ? 'Thinking...' : 'Thought Process',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: primaryColor,
                        ),
                      ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: primaryColor.withAlpha(150),
                        size: 16,
                      ),
                    ),
                  ],
                ),
                // Expandable content inside the same container
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withAlpha(60),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: displayText.isEmpty && isThinking
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Generating thoughts...',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                    color: primaryColor.withAlpha(180),
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
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withAlpha(200),
                              ),
                            ),
                    ),
                  ),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
          ),
        ),
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
