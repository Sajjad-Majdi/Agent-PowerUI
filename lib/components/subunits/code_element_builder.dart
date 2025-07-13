import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:flutter_highlight/themes/atom-one-dark.dart';

class CodeBlock extends StatefulWidget {
  const CodeBlock({
    super.key,
    required this.text,
    required this.language,
  });

  final String text;
  final String language;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _isCopied = false;
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerColor = Colors.grey[300];
    final headerBackgroundColor = theme.colorScheme.onSurface.withAlpha(50);
    final textColor = theme.textTheme.bodyMedium!.color;
    final codeBackground = theme.colorScheme.surface;

// ------------------------------- Highlight View ------------------------------------

    Map<String, TextStyle> _createThemeAwareColors(ThemeData theme) {
      return {
        for (final entry in atomOneDarkTheme.entries) entry.key: entry.value,
      };
    }

    final dynamicTheme = _createThemeAwareColors(theme);

    final parseResult = hl.highlight.parse(
      widget.text,
      language: widget.language,
      autoDetection: true,
    );

    List<InlineSpan> _convertNodes(List<hl.Node>? nodes) {
      if (nodes == null) return [];
      return nodes.map<InlineSpan>((n) {
        return TextSpan(
          style: dynamicTheme[n.className],
          text: n.value,
          children: _convertNodes(n.children),
        );
      }).toList();
    }
// ------------------------------- End Highlight View ------------------------------------

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------- Header ------------------------------------
              Container(
                color: headerBackgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        widget.language,
                        style: GoogleFonts.nunito(
                          color: headerColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: headerColor,
                            padding: EdgeInsets.only(left: 5, right: 10),
                          ),
                          onPressed: () {
                            setState(() => _isCollapsed = !_isCollapsed);
                          },
                          icon: Icon(
                            _isCollapsed
                                ? Icons.expand_more
                                : Icons.expand_less,
                            color: headerColor,
                          ),
                          label: Text(
                            _isCollapsed ? 'Expand' : 'Collapse',
                            style: GoogleFonts.nunito(
                                color: headerColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            foregroundColor: headerColor,
                            padding: EdgeInsets.all(10),
                          ),
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: widget.text));
                            if (!mounted) return;
                            setState(() => _isCopied = true);
                            await Future.delayed(const Duration(seconds: 2));
                            if (mounted) setState(() => _isCopied = false);
                          },
                          icon: Icon(
                            _isCopied
                                ? Icons.check_rounded
                                : Icons.copy_rounded,
                            color: headerColor,
                            size: 16,
                          ),
                          label: Text(
                            _isCopied ? 'Copied!' : 'Copy',
                            style: GoogleFonts.nunito(
                                color: headerColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ------------------------------- Code Block ------------------------------------
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: _isCollapsed ? 0 : 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  color: codeBackground,
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16.0),
                    child: SelectableText.rich(
                      TextSpan(
                        style: GoogleFonts.firaCode(
                            color: textColor, fontSize: 14),
                        children: _convertNodes(parseResult.nodes),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CodeInline extends StatelessWidget {
  final String code;

  const CodeInline({
    super.key,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SelectableText(
          code,
          style: TextStyle(
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withAlpha(25),
            fontFamily: 'monospace',
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
