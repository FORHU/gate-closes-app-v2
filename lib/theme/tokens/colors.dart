import 'package:flutter/material.dart';

/// Design tokens — colors.
///
/// Gate Closes identity: dark, translucent glass surfaces with a single lime
/// accent (`#BBE40A`), ported from `gate-closes-app`'s `styles/GlobalStyles.ts`
/// and `EchoCard` card treatment. Dark is the primary/default identity; light
/// is a complementary palette that keeps the same accent hue rather than a
/// naive inversion.
///
/// Values are exposed as a [ThemeExtension] so screens read them
/// brightness-correctly via `context.colors.*` (see `GateColorsX` in
/// `core/utils/context_extensions.dart`) instead of a fixed static palette.
@immutable
class GateColors extends ThemeExtension<GateColors> {
  const GateColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.accent,
    required this.accentOn,
    required this.accentGlow15,
    required this.accentGlow20,
    required this.accentGlow45,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textSubtle,
    required this.border,
    required this.error,
    required this.errorGlow,
    required this.success,
    required this.warning,
  });

  /// App/scaffold background.
  final Color background;

  /// Card/surface fill — translucent over [background] for the glass look.
  final Color surface;

  /// Raised/elevated surface (sheets, dialogs, popovers).
  final Color surfaceElevated;

  /// Gate Closes brand accent (lime).
  final Color accent;

  /// Foreground color for content placed on top of [accent] fills.
  final Color accentOn;

  final Color accentGlow15;
  final Color accentGlow20;
  final Color accentGlow45;

  /// Full-emphasis text/icons.
  final Color textPrimary;

  /// High-emphasis secondary text (~80% in dark mode).
  final Color textSecondary;

  /// Muted text — timestamps, counters (~40% in dark mode).
  final Color textMuted;

  /// Lowest-emphasis text — de-emphasized labels (~35% in dark mode).
  final Color textSubtle;

  /// Hairline border for cards/dividers.
  final Color border;

  final Color error;
  final Color errorGlow;
  final Color success;
  final Color warning;

  /// Gate Closes dark identity — the primary/default theme.
  static const dark = GateColors(
    background: Color(0xFF111111),
    surface: Color(0xCC141414),
    surfaceElevated: Color(0xFF1A1A1A),
    accent: Color(0xFFBBE40A),
    accentOn: Color(0xFF000000),
    accentGlow15: Color(0x26BBE40A),
    accentGlow20: Color(0x33BBE40A),
    accentGlow45: Color(0x73BBE40A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xCCFFFFFF),
    textMuted: Color(0x66FFFFFF),
    textSubtle: Color(0x59FFFFFF),
    border: Color(0x0DFFFFFF),
    error: Color(0xFFEF4444),
    errorGlow: Color(0x26EF4444),
    success: Color(0xFF34A853),
    warning: Color(0xFFD89614),
  );

  /// Gate Closes light identity — keeps the lime hue (darkened for contrast
  /// on white), not a straight inversion of [dark].
  static const light = GateColors(
    background: Color(0xFFF7F8F4),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    accent: Color(0xFF8FB800),
    accentOn: Color(0xFF000000),
    accentGlow15: Color(0x268FB800),
    accentGlow20: Color(0x338FB800),
    accentGlow45: Color(0x738FB800),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF333333),
    textMuted: Color(0xFF666666),
    textSubtle: Color(0xFF888888),
    border: Color(0x14111111),
    error: Color(0xFFDC2626),
    errorGlow: Color(0x26DC2626),
    success: Color(0xFF2FA36B),
    warning: Color(0xFFD89614),
  );

  @override
  GateColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? accent,
    Color? accentOn,
    Color? accentGlow15,
    Color? accentGlow20,
    Color? accentGlow45,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textSubtle,
    Color? border,
    Color? error,
    Color? errorGlow,
    Color? success,
    Color? warning,
  }) {
    return GateColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      accent: accent ?? this.accent,
      accentOn: accentOn ?? this.accentOn,
      accentGlow15: accentGlow15 ?? this.accentGlow15,
      accentGlow20: accentGlow20 ?? this.accentGlow20,
      accentGlow45: accentGlow45 ?? this.accentGlow45,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      border: border ?? this.border,
      error: error ?? this.error,
      errorGlow: errorGlow ?? this.errorGlow,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  GateColors lerp(ThemeExtension<GateColors>? other, double t) {
    if (other is! GateColors) return this;
    return GateColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentOn: Color.lerp(accentOn, other.accentOn, t)!,
      accentGlow15: Color.lerp(accentGlow15, other.accentGlow15, t)!,
      accentGlow20: Color.lerp(accentGlow20, other.accentGlow20, t)!,
      accentGlow45: Color.lerp(accentGlow45, other.accentGlow45, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorGlow: Color.lerp(errorGlow, other.errorGlow, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
