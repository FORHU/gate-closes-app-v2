import 'package:flutter/material.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/radius.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:gate_closes/theme/tokens/typography.dart';

/// Ported from `gate-closes-app`'s `PrimaryButton`: lime pill button, black
/// label text, 56px height, subtle accent glow, pressed/disabled states.
class AppButtonTheme {
  AppButtonTheme._();

  static ElevatedButtonThemeData build(GateColors colors) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.accentOn,
          disabledBackgroundColor: colors.accent.withValues(alpha: 0.6),
          disabledForegroundColor: colors.accentOn.withValues(alpha: 0.6),
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 18,
            height: 28 / 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      );
}
