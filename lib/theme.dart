import 'package:flutter/material.dart';

class AppTheme {
  static const _defaultMainColor = Color.fromARGB(255, 35, 150, 245);
  static const _privacyMainColor = Color.fromARGB(255, 142, 82, 255);

  static final ValueNotifier<bool> _privacyModeNotifier =
      ValueNotifier<bool>(false);
  static AppColorPalette? _cachedPalette;

  static ValueNotifier<bool> get privacyModeNotifier => _privacyModeNotifier;
  static bool get isPrivacyMode => _privacyModeNotifier.value;

  static void setPrivacyMode(bool enabled) {
    if (_privacyModeNotifier.value != enabled) {
      _privacyModeNotifier.value = enabled;
      _cachedPalette = null;
    }
  }

  static void togglePrivacyMode() {
    setPrivacyMode(!isPrivacyMode);
  }

  static AppColorPalette get colors {
    final baseColor = isPrivacyMode ? _privacyMainColor : _defaultMainColor;
    final palette = _cachedPalette;
    if (palette == null || palette.mainColor != baseColor) {
      _cachedPalette = AppColorPalette(baseColor);
    }
    return _cachedPalette!;
  }

  static Color get currentMainColor => colors.primaryColor;

  static const textStyles = _AppTextStyles();
}

class AppColorPalette {
  AppColorPalette(Color base)
      : mainColor = base,
        _mainHsl = HSLColor.fromColor(base);

  final Color mainColor;
  final HSLColor _mainHsl;

  Color? _backgroundColor;
  Color? _inputBarColor;
  Color? _messageBubbleColor;

  Color get primaryColor => mainColor;

  Color get backgroundColor {
    return _backgroundColor ??= _mainHsl
        .withHue((_mainHsl.hue + 3.953523926) % 360)
        .withSaturation((_mainHsl.saturation * 0.5660010877).clamp(0.0, 1.0))
        .withLightness(0.1.clamp(0.0, 1.0))
        .toColor();
  }

  Color get inputBarColor {
    final bg = backgroundColor;
    final bgHsl = HSLColor.fromColor(bg);
    return _inputBarColor ??= bgHsl
        .withHue((bgHsl.hue + 8.4) % 360)
        .withSaturation((bgHsl.saturation * 0.732).clamp(0.0, 1.0))
        .withLightness((bgHsl.lightness + 0.049).clamp(0.0, 1.0))
        .toColor();
  }

  Color get messageBubbleColor {
    final bg = backgroundColor;
    final bgHsl = HSLColor.fromColor(bg);
    return _messageBubbleColor ??= bgHsl
        .withHue((bgHsl.hue - 0.236) % 360)
        .withSaturation((bgHsl.saturation * 0.79878633).clamp(0.0, 1.0))
        .withLightness((bgHsl.lightness + 0.0784313725).clamp(0.0, 1.0))
        .toColor();
  }
}

class _AppTextStyles {
  const _AppTextStyles();

  get englishMedium => const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  get persianMedium => const TextStyle(
        fontFamily: 'Vazir',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Colors.white,
      );

  get title => const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        fontFamily: 'Nunito',
        letterSpacing: 0.5,
      );
}
