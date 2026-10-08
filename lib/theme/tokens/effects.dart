import 'dart:ui';

import 'package:flutter/material.dart';

/// Design tokens — elevation, shadows, blur, glow and gradient effects,
/// following Chumme's `theme/effects.ts` (deep soft shadows, brand-colored
/// glows, a glossy sheen on cards) in the Gate Closes lime.
class AppEffects {
  AppEffects._();

  /// Standard blur for glassmorphic surfaces. Keep blur layers limited on
  /// lists for performance.
  static const double glassBlur = 18;

  static ImageFilter get glassFilter =>
      ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur);

  /// Deep, soft shadow under floating cards (Chumme `shadow.card`).
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// Heavier shadow for hero surfaces: sheets, glass panels (Chumme
  /// `shadow.premium`).
  static List<BoxShadow> get premiumShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  /// Tighter shadow for smaller raised elements (chips, FABs).
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Subtle shadow for elevated surfaces (light design).
  static List<BoxShadow> get surfaceShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Even glow for CTA buttons, colored by the active theme's accent.
  static List<BoxShadow> accentGlow(Color accentGlow15) => [
        BoxShadow(color: accentGlow15, blurRadius: 20),
      ];

  /// The brand glow cast below a highlighted glass panel (Chumme
  /// `shadow.premiumGlow`).
  static List<BoxShadow> premiumGlow(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.24),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  /// The brand glow under a primary button (Chumme `shadow.btn`).
  static List<BoxShadow> buttonGlow(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  /// Primary button fill: the accent brightening toward the top-left
  /// (Chumme `gradient.brandBtn`).
  static LinearGradient brandButton(Color accent) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(accent, Colors.white, 0.12)!,
          accent,
          Color.lerp(accent, Colors.black, 0.18)!,
        ],
        stops: const [0, 0.5, 1],
      );

  /// Faint top-left gloss over cards (Chumme `gradient.cardSheen`).
  static const LinearGradient cardSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomCenter,
    colors: [Color(0x0DFFFFFF), Color(0x00FFFFFF)],
    stops: [0, 0.4],
  );
}
