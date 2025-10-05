import 'package:flutter/material.dart';
import 'dart:ui';

class StylishAppBar extends StatelessWidget {
  final title;
  final subtitle;
  final Widget?
      subtitleWidget; // optional custom subtitle content (e.g., dropdown)
  final List<String>? geminiModels;
  final String? activeModel;
  final ValueChanged<String>? onSelectModel;
  final Widget? leading;
  final List<Widget>? actions;

  const StylishAppBar(
      {super.key,
      required this.title,
      required this.subtitle,
      this.subtitleWidget,
      this.geminiModels,
      this.activeModel,
      this.onSelectModel,
      this.leading,
      this.actions});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          toolbarHeight: 90,
          leading: leading,
          automaticallyImplyLeading: false,
          actions: actions,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B263B).withValues(alpha: 0.95),
                  Color(0xFF0D1B2A).withValues(alpha: 0.9),
                  Color(0xFF415A77).withValues(alpha: 0.8),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF0D1B2A).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/textures/moroccan.png'),
                  repeat: ImageRepeat.repeat,
                  opacity: 0.15,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
            ),
          ),
          title: Row(
            children: [
              const SizedBox(width: 46),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      this.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Color(0xFF415A77).withValues(alpha: 0.9),
                            offset: const Offset(0, 0),
                            blurRadius: 12,
                          ),
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(2, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.2),
                            Colors.white.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: _buildSubtitleContent(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleContent() {
    final models = geminiModels ?? const [];
    if (models.isNotEmpty && onSelectModel != null) {
      return SizedBox(
        height: 22,
        child: Theme(
          data: ThemeData(
            popupMenuTheme: PopupMenuThemeData(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          child: PopupMenuButton<String>(
            initialValue: activeModel,
            onSelected: onSelectModel,
            elevation: 10,
            offset: const Offset(-24, 28),
            menuPadding: EdgeInsets.zero,
            constraints: const BoxConstraints(maxWidth: 200),
            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: models
                          .map((m) => InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  onSelectModel!(m);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: Text(
                                    m.replaceAll('-', ' '),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontFamily: 'Nunito',
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ];
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activeModel?.replaceAll('-', ' ') ?? subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Nunito',
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.95),
                )
              ],
            ),
          ),
        ),
      );
    }

    if (subtitleWidget != null) {
      return SizedBox(height: 22, child: subtitleWidget);
    }

    return Text(
      this.subtitle,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.9),
        letterSpacing: 0.3,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(1, 1),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }
}
