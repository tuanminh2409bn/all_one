import 'package:flutter/material.dart';

ThemeData buildAllOneTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1AA35A),
      primary: const Color(0xFF1AA35A),
    ),
    fontFamily: 'NotoSansKR',
    fontFamilyFallback: const [
      'Apple SD Gothic Neo',
      'Noto Sans KR',
      'Noto Sans',
      'Roboto',
    ],
  );
  return base.copyWith(
    textTheme: _withMediumDefaults(base.textTheme),
    primaryTextTheme: _withMediumDefaults(base.primaryTextTheme),
  );
}

TextTheme _withMediumDefaults(TextTheme source) => source.copyWith(
  displayLarge: _atLeastMedium(source.displayLarge),
  displayMedium: _atLeastMedium(source.displayMedium),
  displaySmall: _atLeastMedium(source.displaySmall),
  headlineLarge: _atLeastMedium(source.headlineLarge),
  headlineMedium: _atLeastMedium(source.headlineMedium),
  headlineSmall: _atLeastMedium(source.headlineSmall),
  titleLarge: _atLeastMedium(source.titleLarge),
  titleMedium: _atLeastMedium(source.titleMedium),
  titleSmall: _atLeastMedium(source.titleSmall),
  bodyLarge: _atLeastMedium(source.bodyLarge),
  bodyMedium: _atLeastMedium(source.bodyMedium),
  bodySmall: _atLeastMedium(source.bodySmall),
  labelLarge: _atLeastMedium(source.labelLarge),
  labelMedium: _atLeastMedium(source.labelMedium),
  labelSmall: _atLeastMedium(source.labelSmall),
);

TextStyle? _atLeastMedium(TextStyle? style) {
  if (style == null) return null;
  final currentWeight = style.fontWeight;
  if (currentWeight != null && currentWeight.value >= FontWeight.w500.value) {
    return style;
  }
  return style.copyWith(
    fontWeight: FontWeight.w500,
    fontVariations: const [FontVariation('wght', 500)],
  );
}
