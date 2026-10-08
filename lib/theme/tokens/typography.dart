import 'package:flutter/material.dart';

/// Design tokens — typography. Poppins, on Chumme's scale
/// (`modules/chumme-ds/theme/tokens.ts`: display 34/28, title 22, subtitle
/// 17, body 15, small 13, caption 11; bold display with slightly tight
/// tracking).
///
/// Bundled locally as static files (`assets/fonts/`, one per weight,
/// declared in `pubspec.yaml`) — no `google_fonts` runtime fetch.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Poppins';

  /// The base Poppins text theme with our size/weight scale applied.
  static TextTheme get textTheme => _base.apply(fontFamily: fontFamily);

  static const TextTheme _base = TextTheme(
    // Large hero / display titles
    displaySmall: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.2,
    ),
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    // Section / card titles
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.2,
    ),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    // Body
    bodyLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    // Labels / captions
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    ),
  );
}
