import 'package:flutter/material.dart';
import '/theme.dart';

final mainColorHSL = HSLColor.fromColor(AppTheme.colors.backgroundColor);
final mainLightness = mainColorHSL.lightness;

class StylishAppBar extends StatefulWidget {
  final String title;
  final List<String>? geminiModels;
  final String? activeModel;
  final ValueChanged<String>? onSelectModel;

  const StylishAppBar({
    super.key,
    required this.title,
    this.geminiModels,
    this.activeModel,
    this.onSelectModel,
  });

  @override
  State<StylishAppBar> createState() => _StylishAppBarState();
}

class _StylishAppBarState extends State<StylishAppBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [
            mainColorHSL.withLightness(mainLightness + 0.04).toColor(),
            mainColorHSL.withLightness(mainLightness + 0.05).toColor(),
            mainColorHSL.withLightness(mainLightness + 0.08).toColor(),
            mainColorHSL.withLightness(mainLightness + 0.15).toColor(),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Center(
        child: _AppBarTitle(
          titleText: widget.title,
          geminiModels: widget.geminiModels,
          activeModel: widget.activeModel,
          onSelectModel: widget.onSelectModel,
        ),
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  final String titleText;
  final List<String>? geminiModels;
  final String? activeModel;
  final ValueChanged<String>? onSelectModel;

  const _AppBarTitle({
    required this.titleText,
    this.geminiModels,
    this.activeModel,
    this.onSelectModel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(
              titleText,
              style: AppTheme.textStyles.title,
            ),
            const SizedBox(height: 8),
            ModelPicker(
              geminiModels: geminiModels,
              activeModel: activeModel,
              onSelectModel: onSelectModel,
            ),
          ],
        ),
      ],
    );
  }
}

class ModelPicker extends StatelessWidget {
  final List<String>? geminiModels;
  final String? activeModel;
  final ValueChanged<String>? onSelectModel;

  const ModelPicker({
    super.key,
    this.geminiModels,
    this.activeModel,
    this.onSelectModel,
  });

  @override
  Widget build(BuildContext context) {
    final models = geminiModels ?? const [];
    if (models.isNotEmpty && onSelectModel != null) {
      return Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.2),
              Colors.white.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
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
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            offset: const Offset(-24, 28),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activeModel?.replaceAll('-', ' ') ?? '',
                  style: AppTheme.textStyles.englishMedium,
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
            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
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
                                      horizontal: 10, vertical: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      m.replaceAll('-', ' '),
                                      style: AppTheme.textStyles.englishMedium,
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ];
            },
          ),
        ),
      );
    }

    return Text('could not load models');
  }
}
