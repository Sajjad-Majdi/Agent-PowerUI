import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'settings_dialog.dart';

class SettingsButton extends StatefulWidget {
  final VoidCallback? onSettingsClosed;

  const SettingsButton({Key? key, this.onSettingsClosed}) : super(key: key);

  @override
  State<SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<SettingsButton> {
  bool _isHovered = false;

  void _showSettingsDialog() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => const SettingsDialog(),
    );
    // Call the callback when dialog closes
    widget.onSettingsClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: _showSettingsDialog,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.transparent,
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(Iconsax.setting,
                  size: 20, color: theme.colorScheme.onSurface),
              SizedBox(width: 12),
              Text('Settings',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Nunito',
                      color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}
