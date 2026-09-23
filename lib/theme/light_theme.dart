import 'package:flutter/material.dart';
import 'package:flutter_template/theme/components/button_theme.dart';
import 'package:flutter_template/theme/components/card_theme.dart';
import 'package:flutter_template/theme/components/input_theme.dart';
import 'package:flutter_template/theme/tokens/colors.dart';
import 'package:flutter_template/theme/tokens/typography.dart';

/// Gate Closes light theme — a complementary palette that keeps the lime
/// brand hue (darkened for contrast on white), not a straight inversion of
/// the dark theme.
class LightTheme {
  LightTheme._();

  static ThemeData build() {
    const colors = GateColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      extensions: const [colors],
      colorScheme: ColorScheme.light(
        primary: colors.accent,
        onPrimary: colors.accentOn,
        secondary: colors.accent,
        onSecondary: colors.accentOn,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        surfaceContainerHighest: colors.surfaceElevated,
        outline: colors.border,
        error: colors.error,
        onError: colors.textPrimary,
      ),
      scaffoldBackgroundColor: colors.background,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: colors.textPrimary,
        displayColor: colors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleTextStyle: AppTypography.textTheme.titleLarge?.copyWith(
          color: colors.textPrimary,
        ),
      ),
      elevatedButtonTheme: AppButtonTheme.build(colors),
      inputDecorationTheme: AppInputTheme.build(colors),
      cardTheme: AppCardTheme.build(colors),
    );
  }
}
