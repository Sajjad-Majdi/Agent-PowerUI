import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class MathBuilder extends StatelessWidget {
  final String tex;
  final TextStyle textStyle;
  final bool inline;

  const MathBuilder({
    super.key,
    required this.tex,
    required this.textStyle,
    required this.inline,
  });

  @override
  Widget build(BuildContext context) {
    return this.inline
        ? _mathTex()
        : MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 5),
                alignment: Alignment.center,
                child: _mathTex(),
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(text: tex));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    elevation: 3,
                    duration: Duration(milliseconds: 800),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Theme.of(context).cardColor,
                    content: Text(
                      '$tex Copied to clipboard',
                      style: textStyle,
                    ),
                  ),
                );
              },
            ),
          );
  }

  Directionality _mathTex() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(tex,
            textStyle: textStyle.copyWith(
              fontSize: inline ? 18 : 22,
            ),
            mathStyle: inline ? MathStyle.display : MathStyle.text),
      ),
    );
  }
}
