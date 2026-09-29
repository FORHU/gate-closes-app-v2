import 'package:flutter/material.dart';

/// Design tokens — typography. Plus Jakarta Sans (ported from
/// `gate-closes-app`'s `FontFamily` in `styles/GlobalStyles.ts`, which uses
/// weights 400/500/600/700/800), premium scale (bold large titles, medium
/// body, small subtle labels).
///
/// Bundled locally as a variable font (`assets/fonts/`, declared in
/// `pubspec.yaml`) — no `google_fonts` runtime fetch. One file's weight axis
/// (200-800) covers every weight below; no separate per-weight assets
/// needed.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'PlusJakartaSans';

  /// The base Plus Jakarta Sans text theme with our size/weight scale
  /// applied.
  static TextTheme get textTheme => _base.apply(fontFamily: fontFamily);

  static const TextTheme _base = TextTheme(
    // Large hero / display titles
    displaySmall: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: -0.5,
    ),
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    // Section / card titles
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    // Body
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
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
