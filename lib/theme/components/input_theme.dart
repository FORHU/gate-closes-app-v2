import 'package:flutter/material.dart';
import 'package:flutter_template/theme/tokens/colors.dart';

class AppInputTheme {
  AppInputTheme._();

  static InputDecorationTheme build(GateColors colors) => InputDecorationTheme(
        fillColor: colors.surface,
        filled: true,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      );
}
