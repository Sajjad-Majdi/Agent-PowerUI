import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/theme.dart';

class StylishAppBar extends StatelessWidget {
  final String title;
  final List<String> geminiModels;
  final List<LocalModelInfo> localModels;
  final String? activeGeminiModel;
  final String? activeLocalModel;
  final bool privacyMode;
  final bool localRunning;
  final bool localBusy;
  final ValueChanged<String>? onSelectGeminiModel;
  final ValueChanged<String>? onSelectLocalModel;
  final VoidCallback? onTogglePrivacyMode;
  final VoidCallback? onTerminateLocal;

  const StylishAppBar({
    super.key,
    required this.title,
    required this.geminiModels,
    required this.localModels,
    required this.activeGeminiModel,
    required this.activeLocalModel,
    required this.privacyMode,
    required this.localRunning,
    required this.localBusy,
    this.onSelectGeminiModel,
    this.onSelectLocalModel,
    this.onTogglePrivacyMode,
    this.onTerminateLocal,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.colors;
    final backgroundHsl = HSLColor.fromColor(palette.backgroundColor);
    final lightness = backgroundHsl.lightness;

    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [
            backgroundHsl
                .withLightness((lightness + 0.04).clamp(0.0, 1.0))
                .toColor(),
            backgroundHsl
                .withLightness((lightness + 0.05).clamp(0.0, 1.0))
                .toColor(),
            backgroundHsl
                .withLightness((lightness + 0.08).clamp(0.0, 1.0))
                .toColor(),
            backgroundHsl
                .withLightness((lightness + 0.15).clamp(0.0, 1.0))
                .toColor(),
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
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _AppBarTitle(
                titleText: title,
                geminiModels: geminiModels,
                localModels: localModels,
                activeGeminiModel: activeGeminiModel,
                activeLocalModel: activeLocalModel,
                privacyMode: privacyMode,
                localBusy: localBusy,
                localRunning: localRunning,
                onSelectGeminiModel: onSelectGeminiModel,
                onSelectLocalModel: onSelectLocalModel,
                onTerminateLocal: onTerminateLocal,
              ),
            ),
          ),
          Positioned(
            right: 24,
            top: 0,
            bottom: 0,
            child: _PrivacyControls(
              privacyMode: privacyMode,
              localBusy: localBusy,
              onTogglePrivacyMode: onTogglePrivacyMode,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  final String titleText;
  final List<String> geminiModels;
  final List<LocalModelInfo> localModels;
  final String? activeGeminiModel;
  final String? activeLocalModel;
  final bool privacyMode;
  final bool localBusy;
  final bool localRunning;
  final ValueChanged<String>? onSelectGeminiModel;
  final ValueChanged<String>? onSelectLocalModel;
  final VoidCallback? onTerminateLocal;

  const _AppBarTitle({
    required this.titleText,
    required this.geminiModels,
    required this.localModels,
    required this.activeGeminiModel,
    required this.activeLocalModel,
    required this.privacyMode,
    required this.localBusy,
    required this.localRunning,
    this.onSelectGeminiModel,
    this.onSelectLocalModel,
    this.onTerminateLocal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          titleText,
          style: AppTheme.textStyles.title,
        ),
        const SizedBox(height: 8),
        ModelPicker(
          privacyMode: privacyMode,
          geminiModels: geminiModels,
          localModels: localModels,
          activeGeminiModel: activeGeminiModel,
          activeLocalModel: activeLocalModel,
          localBusy: localBusy,
          localRunning: localRunning,
          onSelectGeminiModel: onSelectGeminiModel,
          onSelectLocalModel: onSelectLocalModel,
          onTerminateLocal: onTerminateLocal,
        ),
      ],
    );
  }
}

class ModelPicker extends StatelessWidget {
  final bool privacyMode;
  final List<String> geminiModels;
  final List<LocalModelInfo> localModels;
  final String? activeGeminiModel;
  final String? activeLocalModel;
  final bool localBusy;
  final bool localRunning;
  final ValueChanged<String>? onSelectGeminiModel;
  final ValueChanged<String>? onSelectLocalModel;
  final VoidCallback? onTerminateLocal;

  const ModelPicker({
    super.key,
    required this.privacyMode,
    required this.geminiModels,
    required this.localModels,
    required this.activeGeminiModel,
    required this.activeLocalModel,
    required this.localBusy,
    required this.localRunning,
    this.onSelectGeminiModel,
    this.onSelectLocalModel,
    this.onTerminateLocal,
  });

  @override
  Widget build(BuildContext context) {
    if (privacyMode) {
      if (localBusy) {
        return const _BusyIndicator(label: 'Preparing local model...');
      }
      if (localModels.isEmpty) {
        return const Text('No local models found');
      }
      final selectedValue = activeLocalModel ?? localModels.first.name;
      final selectedInfo = _formatModelName(selectedValue);
      final picker = _PickerContainer(
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedInfo.displayName,
              style: AppTheme.textStyles.englishMedium,
              overflow: TextOverflow.ellipsis,
            ),
            if (selectedInfo.parameterLabel != null)
              Text(
                selectedInfo.parameterLabel!,
                style: AppTheme.textStyles.englishMedium.copyWith(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        selectedValue: selectedValue,
        items: localModels.map(
          (model) {
            final info = _formatModelName(model.name);
            return _PickerItem(
              value: model.name,
              title: info.displayName,
              subtitle: model.humanReadableSize,
              showTerminate: localRunning && activeLocalModel == model.name,
              onTerminate: onTerminateLocal,
            );
          },
        ).toList(),
        onSelect: onSelectLocalModel,
        expandable: true,
      );
      final showTerminateButton =
          localRunning && activeLocalModel == selectedValue;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          picker,
          if (showTerminateButton && onTerminateLocal != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Terminate local model',
              child: IconButton(
                onPressed: onTerminateLocal,
                icon: const Icon(Icons.power_settings_new),
                splashRadius: 18,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      );
    }

    if (geminiModels.isEmpty || onSelectGeminiModel == null) {
      return const Text('Could not load models');
    }

    return _PickerContainer(
      label: Text(
        (activeGeminiModel ?? geminiModels.first).replaceAll('-', ' '),
        style: AppTheme.textStyles.englishMedium,
        overflow: TextOverflow.ellipsis,
      ),
      selectedValue: activeGeminiModel ?? geminiModels.first,
      items: geminiModels
          .map(
            (model) => _PickerItem(
              value: model,
              title: model.replaceAll('-', ' '),
            ),
          )
          .toList(),
      onSelect: onSelectGeminiModel,
    );
  }

  _FormattedModelName _formatModelName(String fileName) {
    var base =
        fileName.replaceAll(RegExp(r'\\.gguf$', caseSensitive: false), '');
    final parts = base.split(RegExp(r'[_\\-]+'));
    final nameParts = <String>[];
    for (final rawPart in parts) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;
      // Match parameter size like "4B"
      final paramMatch = RegExp(r'^(\\d+(?:\\.\\d+)?)[bB]$').firstMatch(part);
      if (paramMatch != null) {
        nameParts.add('${paramMatch.group(1)}B');
        continue;
      }
      // Stop at quantization tokens like "Q4", "K", "M" or version numbers
      if (RegExp(r'^[Qq]\\d').hasMatch(part) ||
          RegExp(r'^[KkMm]$').hasMatch(part) ||
          RegExp(r'^\\d{4}$').hasMatch(part)) {
        break;
      }
      nameParts.add(part);
    }
    if (nameParts.isEmpty) {
      base = base.replaceAll(RegExp(r'[_\\-]+'), ' ').trim();
      return _FormattedModelName(base, null);
    }
    final display = nameParts.join(' ');
    return _FormattedModelName(display, null);
  }
}

class _FormattedModelName {
  final String displayName;
  final String? parameterLabel;

  const _FormattedModelName(this.displayName, this.parameterLabel);
}

class _PickerItem {
  final String value;
  final String title;
  final String? subtitle;
  final bool showTerminate;
  final VoidCallback? onTerminate;

  const _PickerItem({
    required this.value,
    required this.title,
    this.subtitle,
    this.showTerminate = false,
    this.onTerminate,
  });
}

class _PickerContainer extends StatelessWidget {
  final Widget label;
  final String? selectedValue;
  final List<_PickerItem> items;
  final ValueChanged<String>? onSelect;
  final bool expandable;

  const _PickerContainer({
    required this.label,
    required this.selectedValue,
    required this.items,
    required this.onSelect,
    this.expandable = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentValue =
        selectedValue ?? (items.isNotEmpty ? items.first.value : null);
    final container = Container(
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        child: PopupMenuButton<String>(
          initialValue: currentValue,
          enabled: onSelect != null,
          onSelected: onSelect,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          offset: const Offset(-24, 28),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: label,
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.95),
              ),
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
                    children: items
                        .map(
                          (item) => InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              onSelect?.call(item.value);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style:
                                              AppTheme.textStyles.englishMedium,
                                        ),
                                        if (item.subtitle != null)
                                          Text(
                                            item.subtitle!,
                                            style: AppTheme
                                                .textStyles.englishMedium
                                                .copyWith(
                                                    fontSize: 12.0,
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.7)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (item.showTerminate &&
                                      item.onTerminate != null)
                                    Tooltip(
                                      message: 'Terminate local model',
                                      child: IconButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          item.onTerminate?.call();
                                        },
                                        icon: const Icon(
                                          Icons.power_settings_new,
                                          size: 18,
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ];
          },
        ),
      ),
    );

    if (expandable) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 200),
        child: container,
      );
    }
    return container;
  }
}

class _PrivacyControls extends StatelessWidget {
  final bool privacyMode;
  final bool localBusy;
  final VoidCallback? onTogglePrivacyMode;

  const _PrivacyControls({
    required this.privacyMode,
    required this.localBusy,
    this.onTogglePrivacyMode,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        onPressed: localBusy ? null : onTogglePrivacyMode,
        icon: localBusy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                privacyMode ? Icons.lock : Icons.lock_open,
                size: 24,
                color: Colors.white.withValues(alpha: 0.9),
              ),
        tooltip: 'Privacy Mode',
        style: IconButton.styleFrom(
          backgroundColor: privacyMode
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.1),
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}

class _BusyIndicator extends StatelessWidget {
  final String label;

  const _BusyIndicator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTheme.textStyles.englishMedium.copyWith(fontSize: 14.0),
        ),
      ],
    );
  }
}
