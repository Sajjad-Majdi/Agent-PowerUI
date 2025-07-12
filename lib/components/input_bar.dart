import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// فرض می‌شود این فایل شامل تابع isRTL است
// import 'subunits/utilities.dart';
import 'package:google_fonts/google_fonts.dart';

// یک پیاده‌سازی ساده از isRTL برای اینکه کد قابل اجرا باشد
// کاربر باید پیاده‌سازی واقعی خود را جایگزین کند
bool isRTL(String text) {
  if (text.isEmpty) return false;
  final firstChar = text.runes.first;
  // محدوده‌ی مثال برای حروف عربی و فارسی
  return (firstChar >= 0x0600 && firstChar <= 0x06FF);
}

/// یک InputBar ساده که یک controller و یک callback به نام onSend می‌گیرد.
class InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const InputBar({
    Key? key,
    required this.controller,
    required this.onSend,
  }) : super(key: key);

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final int _maxLines = 6;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final inputDecorationTheme = theme.inputDecorationTheme;
    final bool _isTextRTL = isRTL(widget.controller.text);
    final bool _hasText = widget.controller.text.trim().isNotEmpty;

    final containerColor = inputDecorationTheme.fillColor ??
        (isDarkMode ? theme.colorScheme.surfaceContainerHigh : Colors.white);
    final shadowColor = theme.colorScheme.shadow;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        );
        final textSpan =
            TextSpan(text: widget.controller.text, style: textStyle);
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
            color: containerColor,
            borderRadius: BorderRadius.circular(28.0),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withAlpha(
                  isDarkMode ? 128 : 51,
                ),
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
              IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.attach_file_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 22,
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
                    // تغییر اکشن کیبورد مجازی به "رفتن به خط بعد" برای هماهنگی
                    textInputAction: TextInputAction.newline,
                    // onSubmitted دیگر نیازی نیست چون Enter به خط بعد می‌رود
                    onSubmitted: null,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.4,
                      fontFamily: _isTextRTL
                          ? 'Vazir'
                          : GoogleFonts.nunito().fontFamily,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: inputDecorationTheme.hintStyle,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: false,
                    ),
                    keyboardAppearance:
                        isDarkMode ? Brightness.dark : Brightness.light,
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
                    // همچنین دکمه ارسال با کلیک هم کار می‌کند
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
