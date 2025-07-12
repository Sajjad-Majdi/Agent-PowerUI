import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkBuilder extends StatefulWidget {
  const LinkBuilder({
    super.key,
    required this.linkText,
    required this.url,
    required this.style,
  });

  final String linkText;
  final String url;
  final TextStyle style;

  @override
  State<LinkBuilder> createState() => _LinkBuilderState();
}

class _LinkBuilderState extends State<LinkBuilder> {
  bool isHovered = false;
  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: ButtonStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        minimumSize: WidgetStateProperty.all(Size.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
      onHover: (value) {
        setState(() {
          isHovered = value;
        });
      },
      onPressed: () async {
        final uri = Uri.parse(widget.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        widget.linkText,
        style: widget.style.copyWith(
          color: Colors.blue,
          decoration: isHovered ? TextDecoration.underline : null,
        ),
      ),
    );
  }
}
