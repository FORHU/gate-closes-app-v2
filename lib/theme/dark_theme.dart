import 'package:flutter/material.dart';
import 'package:gate_closes/theme/components/button_theme.dart';
import 'package:gate_closes/theme/components/card_theme.dart';
import 'package:gate_closes/theme/components/input_theme.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/typography.dart';

/// Gate Closes dark theme — the primary/default identity, ported from
/// `gate-closes-app` (dark background, lime accent, glass surfaces).
class DarkTheme {
  DarkTheme._();

  static ThemeData build() {
    const colors = GateColors.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: const [colors],
      colorScheme: ColorScheme.dark(
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
