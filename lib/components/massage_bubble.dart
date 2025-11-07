import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:gpt_markdown/custom_widgets/selectable_adapter.dart';
import 'package:iconsax/iconsax.dart';
import '/theme.dart';
import '/components/subunits/utilities.dart';
import '/components/subunits/code_element_builder.dart';
import '/components/subunits/math_element_builder.dart';
import '/components/subunits/link_element_builder.dart';
import '/components/subunits/tool_call_builder.dart';

class MessageBubble extends StatefulWidget {
  final String message;
  final bool isMe;
  final bool isLoading;
  final Map<String, dynamic>? toolCall;
  final Map<String, ToolCallState>? toolCallStates;

  const MessageBubble({
    super.key,
    required this.message,
    this.isMe = false,
    this.isLoading = false,
    this.toolCall,
    this.toolCallStates,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool isHovered = false;
  bool isCopied = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final persianMedium = AppTheme.textStyles.persianMedium;
    final englishMedium = AppTheme.textStyles.englishMedium;

    // Legacy tool call display (for backward compatibility)
    if (widget.toolCall != null) {
      return Container(
        alignment: Alignment.centerLeft,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: ToolCallBuilder(
          toolName: widget.toolCall!['name'] ?? 'Unknown Tool',
          toolArgs: Map<String, dynamic>.from(widget.toolCall!['args'] ?? {}),
          status: 'done',
          steps: const <ToolStepState>[],
        ),
      );
    }

    final isRtl = isRTL(widget.message);

    // Build content with mixed text and tool calls
    Widget buildMessageContent() {
      // If message has embedded tool calls, parse and render
      if (!widget.isMe && widget.message.contains('<tool_call')) {
        final segments = parseMessageWithToolCalls(widget.message);
        final toolStates = widget.toolCallStates ?? {};

        return Column(
          crossAxisAlignment:
              isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: segments.map((segment) {
            if (segment.type == 'text') {
              return SelectionArea(
                child: GptMarkdown(
                  segment.text!,
                  followLinkColor: true,
                  useDollarSignsForLatex: true,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontFamily: isRtl ? 'Vazir' : 'Nunito',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  onLinkTap: (url, title) async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } else {
                      debugPrint('Could not launch $uri');
                    }
                  },
                  highlightBuilder: (context, text, style) {
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      child: Text(text, style: style.copyWith(fontSize: 14)),
                    );
                  },
                  codeBuilder: (context, name, code, closed) {
                    if (closed) {
                      return CodeBlock(text: code, language: name);
                    }
                    return SelectableAdapter(
                      selectedText: code,
                      child: CodeInline(code: code),
                    );
                  },
                  linkBuilder: (context, text, url, style) {
                    final linkText = text.toPlainText();
                    return LinkBuilder(
                        linkText: linkText, url: url, style: style);
                  },
                  latexBuilder: (context, tex, style, inline) {
                    return SelectableAdapter(
                      selectedText: tex,
                      child: MathBuilder(
                          tex: tex, textStyle: style, inline: inline),
                    );
                  },
                ),
              );
            } else {
              // Render tool call
              final toolState = toolStates[segment.toolId];
              if (toolState != null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ToolCallBuilder(
                    toolName: toolState.toolName,
                    toolArgs: toolState.toolArgs,
                    status: toolState.status,
                    steps: toolState.steps,
                    currentTool: toolState.currentTool,
                    resultText: toolState.resultText,
                  ),
                );
              }
              return SizedBox.shrink();
            }
          }).toList(),
        );
      }

      // Otherwise, render as regular markdown
      return SelectionArea(
        child: GptMarkdown(
          widget.message,
          followLinkColor: true,
          useDollarSignsForLatex: true,
          style: isRtl ? persianMedium : englishMedium,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          onLinkTap: (url, title) async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              debugPrint('Could not launch $uri');
            }
          },
          highlightBuilder: (context, text, style) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(text, style: style.copyWith(fontSize: 14)),
            );
          },
          codeBuilder: (context, name, code, closed) {
            if (closed) {
              return CodeBlock(text: code, language: name);
            }
            return SelectableAdapter(
              selectedText: code,
              child: CodeInline(code: code),
            );
          },
          linkBuilder: (context, text, url, style) {
            final linkText = text.toPlainText();
            return LinkBuilder(linkText: linkText, url: url, style: style);
          },
          latexBuilder: (context, tex, style, inline) {
            return SelectableAdapter(
              selectedText: tex,
              child: MathBuilder(tex: tex, textStyle: style, inline: inline),
            );
          },
        ),
      );
    }

    final contentWidget = buildMessageContent();

    if (widget.isMe) {
      return LayoutBuilder(builder: (context, constraints) {
        return Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * 0.8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.colors.messageBubbleColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: contentWidget,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: CopyButton(
                      text: widget.message, alignment: Alignment.centerRight),
                ),
              ],
            ),
          ),
        );
      });
    } else {
      return Container(
        alignment: Alignment.centerLeft,
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: widget.isLoading
            ? Container(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Column(
                crossAxisAlignment:
                    isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(child: contentWidget),
                  if (!widget.message.contains('<tool_call'))
                    CopyButton(text: widget.message),
                ],
              ),
      );
    }
  }
}

// --------------------------- Copy Button ------------------------------------
class CopyButton extends StatefulWidget {
  final String text;
  final Alignment? alignment;
  const CopyButton({super.key, required this.text, this.alignment});

  @override
  _CopyButtonState createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool isHovered = false;
  bool isCopied = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) => setState(() => isHovered = true),
      onExit: (event) => setState(() => isHovered = false),
      child: Container(
        width: double.infinity,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 200),
          tween: Tween<double>(begin: 0, end: isHovered ? 1 : 0),
          builder: (context, value, child) {
            return Opacity(opacity: value, child: child);
          },
          child: Align(
            alignment: widget.alignment ?? Alignment.centerLeft,
            child: SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                  style: IconButton.styleFrom(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.text));
                    setState(() {
                      isCopied = true;
                    });
                    Future.delayed(const Duration(seconds: 1), () {
                      setState(() {
                        isCopied = false;
                      });
                    });
                  },
                  icon: isCopied
                      ? const Icon(Iconsax.check)
                      : const Icon(Iconsax.copy)),
            ),
          ),
        ),
      ),
    );
  }
}
