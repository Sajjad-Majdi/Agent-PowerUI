import 'package:flutter/material.dart';

class AppTheme {
  static const colors = _AppColors();
  static const textStyles = _AppTextStyles();
}

class _AppColors {
  const _AppColors();
  final mainColor = const Color.fromARGB(255, 35, 150, 245);
  get primaryColor => mainColor;
  get backgroundColor => HSLColor.fromColor(mainColor)
      .withHue((HSLColor.fromColor(mainColor).hue + 3.953523926) % 360)
      .withSaturation((HSLColor.fromColor(mainColor).saturation * 0.5660010877)
          .clamp(0.0, 1.0))
      .withLightness(0.1.clamp(0.0, 1.0))
      .toColor();
  get inputBarColor => HSLColor.fromColor(backgroundColor)
      .withHue((HSLColor.fromColor(backgroundColor).hue + 8.4) % 360)
      .withSaturation((HSLColor.fromColor(backgroundColor).saturation * 0.732)
          .clamp(0.0, 1.0))
      .withLightness((HSLColor.fromColor(backgroundColor).lightness + 0.049)
          .clamp(0.0, 1.0))
      .toColor();
  get messageBubbleColor => HSLColor.fromColor(backgroundColor)
      .withHue((HSLColor.fromColor(backgroundColor).hue - 0.236) % 360)
      .withSaturation(
          (HSLColor.fromColor(backgroundColor).saturation * 0.79878633)
              .clamp(0.0, 1.0))
      .withLightness(
          (HSLColor.fromColor(backgroundColor).lightness + 0.0784313725)
              .clamp(0.0, 1.0))
      .toColor();
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
