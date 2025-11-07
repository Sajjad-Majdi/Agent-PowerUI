import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '/components/subunits/utilities.dart';
import 'tool_box.dart';
import '/services/api_service.dart';
import '/theme.dart';

class InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const InputBar({Key? key, required this.controller, required this.onSend})
      : super(key: key);

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final int _maxLines = 6;
  bool _isHovering = false;
  List<Map<String, dynamic>> _tools = [];
  bool _toolsLoading = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    widget.controller.addListener(() => setState(() {}));
    _loadTools();
  }

  Future<void> _loadTools() async {
    if (_toolsLoading) return;
    setState(() => _toolsLoading = true);

    const int maxAttempts = 8;
    Duration delay = const Duration(milliseconds: 250);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final tools = await ApiService.getTools();
        setState(() => _tools = tools);
        break;
      } catch (e) {
        // If last attempt, just log and exit loop
        if (attempt == maxAttempts) {
          print('Error loading tools (final): $e');
          break;
        }
        // Exponential backoff
        await Future.delayed(delay);
        delay *= 2;
      }
    }

    setState(() => _toolsLoading = false);
  }

  void _showToolsBox(BuildContext context) {
    if (_tools.isEmpty && !_toolsLoading) {
      // Lazy refresh right before showing the box
      _loadTools();
    }
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset position =
        button.localToGlobal(Offset.zero, ancestor: overlay);

    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(102),
      builder: (context) => Stack(
        children: [
          Positioned(
            left: position.dx,
            bottom: overlay.size.height - position.dy + 8,
            child: Material(
              color: Colors.transparent,
              child: ToolBox(
                tools: _tools,
                isLoading: _toolsLoading,
                onRefresh: _loadTools,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bool _isTextRTL = isRTL(widget.controller.text);
    final bool _hasText = widget.controller.text.trim().isNotEmpty;

    final inputBarColor = AppTheme.colors.inputBarColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final persianMedium = AppTheme.textStyles.persianMedium;
        final englishMedium = AppTheme.textStyles.englishMedium;

        final textSpan = TextSpan(
          text: widget.controller.text,
          style: _isTextRTL ? persianMedium : englishMedium,
        );
        final tp = TextPainter(
          text: textSpan,
          maxLines: _maxLines,
          textDirection: _isTextRTL ? TextDirection.rtl : TextDirection.ltr,
          textWidthBasis: TextWidthBasis.parent,
        )..layout(minWidth: 0, maxWidth: constraints.maxWidth - 120);
        final bool isExpanded = tp.computeLineMetrics().length > 1;

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: inputBarColor,
            borderRadius: BorderRadius.circular(28.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                offset: const Offset(0, 6),
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color: _focusNode.hasFocus
                  ? theme.colorScheme.primary.withAlpha(153)
                  : theme.colorScheme.outlineVariant.withAlpha(102),
              width: _focusNode.hasFocus ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment:
                isExpanded ? CrossAxisAlignment.end : CrossAxisAlignment.center,
            children: [
              Builder(
                builder: (context) => IconButton(
                  onPressed: () => _showToolsBox(context),
                  tooltip: 'Tools Box',
                  icon: Icon(
                    Iconsax.setting_4,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
              ),
              Expanded(
                child: Focus(
                  focusNode: _focusNode,
                  onKeyEvent: (node, event) {
                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      if (HardwareKeyboard.instance.isShiftPressed) {
                        return KeyEventResult.ignored;
                      }
                      widget.onSend();
                      return KeyEventResult.handled;
                    }

                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: widget.controller,
                    textDirection:
                        _isTextRTL ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: _isTextRTL ? TextAlign.right : TextAlign.left,
                    onChanged: (_) => setState(() {}),
                    maxLines: _maxLines,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: null,
                    style: _isTextRTL ? persianMedium : englishMedium,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: false,
                    ),
                    keyboardAppearance: Brightness.light,
                  ),
                ),
              ),
              AnimatedScale(
                scale: _hasText ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isHovering = true),
                  onExit: (_) => setState(() => _isHovering = false),
                  child: GestureDetector(
                    onTap: widget.onSend,
                    child: Container(
                      margin: EdgeInsets.only(
                        left: 3,
                        right: 3,
                        bottom: isExpanded ? 2 : 0,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isHovering
                            ? theme.colorScheme.primary.withAlpha(190)
                            : theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withAlpha(76),
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: theme.colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
