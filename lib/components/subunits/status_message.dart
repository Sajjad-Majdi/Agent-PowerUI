import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:async';

enum StatusType { success, error, info, warning }

class StatusMessage extends StatefulWidget {
  final String message;
  final StatusType type;
  final VoidCallback? onDismiss;
  final Duration? autoDismissDuration;

  const StatusMessage({
    Key? key,
    required this.message,
    this.type = StatusType.info,
    this.onDismiss,
    this.autoDismissDuration = const Duration(seconds: 4),
  }) : super(key: key);

  @override
  State<StatusMessage> createState() => _StatusMessageState();
}

class _StatusMessageState extends State<StatusMessage> {
  Timer? _timer;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    if (widget.autoDismissDuration != null && widget.onDismiss != null) {
      _timer = Timer(widget.autoDismissDuration!, () {
        if (mounted) {
          setState(() => _isVisible = false);
          // Give time for fade out animation
          Future.delayed(Duration(milliseconds: 300), () {
            if (mounted) widget.onDismiss?.call();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleDismiss() {
    _timer?.cancel();
    setState(() => _isVisible = false);
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color textColor;
    Color iconColor;
    IconData icon;

    switch (widget.type) {
      case StatusType.success:
        backgroundColor = Colors.green.withValues(alpha: 0.15);
        textColor = Colors.green.shade700;
        iconColor = Colors.green;
        icon = Iconsax.tick_circle;
        break;
      case StatusType.error:
        backgroundColor = Colors.red.withValues(alpha: 0.15);
        textColor = Colors.red.shade700;
        iconColor = Colors.red;
        icon = Iconsax.close_circle;
        break;
      case StatusType.warning:
        backgroundColor = Colors.orange.withValues(alpha: 0.15);
        textColor = Colors.orange.shade700;
        iconColor = Colors.orange;
        icon = Iconsax.warning_2;
        break;
      case StatusType.info:
        backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.15);
        textColor = theme.colorScheme.primary;
        iconColor = theme.colorScheme.primary;
        icon = Iconsax.information;
        break;
    }

    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.message,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (widget.onDismiss != null)
              IconButton(
                icon: Icon(Iconsax.close_square, size: 16),
                color: textColor.withValues(alpha: 0.7),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                onPressed: _handleDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
