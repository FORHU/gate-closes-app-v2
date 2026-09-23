import 'dart:ui';

import 'package:flutter/material.dart';

/// Design tokens — elevation, shadows, blur and glow effects.
class AppEffects {
  AppEffects._();

  /// Standard blur for glassmorphic surfaces. Keep blur layers limited on
  /// lists for performance.
  static const double glassBlur = 18;

  static ImageFilter get glassFilter =>
      ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur);

  /// Soft, low-opacity shadow used by floating cards.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
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

  /// Primary glow shadow for CTA buttons — colored by the active theme's
  /// accent, matching `gate-closes-app`'s `PrimaryButton` lime drop-shadow
  /// (`0px 0px 20px rgba(249, 228, 6, 0.15)`).
  static List<BoxShadow> accentGlow(Color accentGlow15) => [
        BoxShadow(color: accentGlow15, blurRadius: 20),
      ];
}
