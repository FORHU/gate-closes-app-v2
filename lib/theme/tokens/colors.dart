import 'package:flutter/material.dart';

/// Design tokens — colors.
///
/// Gate Closes identity on the Chumme design language (`chumme-app-v3`
/// `modules/chumme-ds/theme/tokens.ts`): deep maroon surfaces stepping up in
/// layers, frosted glass, white hairlines and warm "fog" text, with the
/// Gate Closes lime (`#BBE40A`) as the one brand color. Dark is the
/// primary/default identity; light keeps the same accent hue rather than a
/// naive inversion.
///
/// Values are exposed as a [ThemeExtension] so screens read them
/// brightness-correctly via `context.colors.*` (see `GateColorsX` in
/// `core/utils/context_extensions.dart`) instead of a fixed static palette.
@immutable
class GateColors extends ThemeExtension<GateColors> {
  const GateColors({
    required this.background,
    required this.backgroundCanvas,
    required this.surface,
    required this.surfaceElevated,
    required this.surfacePressed,
    required this.glass,
    required this.glassStrong,
    required this.accent,
    required this.accentOn,
    required this.accentGlow15,
    required this.accentGlow20,
    required this.accentGlow45,
    required this.accentWarm,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textSubtle,
    required this.border,
    required this.borderStrong,
    required this.hairline,
    required this.error,
    required this.errorGlow,
    required this.success,
    required this.warning,
  });

  /// App/scaffold background.
  final Color background;

  /// A step up from [background]: grouped sections, list backdrops.
  final Color backgroundCanvas;

  /// Card/surface fill.
  final Color surface;

  /// Raised/elevated surface (sheets, dialogs, popovers, hovered cards).
  final Color surfaceElevated;

  /// A surface while pressed.
  final Color surfacePressed;

  /// Frosted glass tint, drawn over a blur.
  final Color glass;

  /// Denser glass for small controls that must stay legible over anything.
  final Color glassStrong;

  /// Gate Closes brand accent (lime).
  final Color accent;

  /// Foreground color for content placed on top of [accent] fills.
  final Color accentOn;

  final Color accentGlow15;
  final Color accentGlow20;
  final Color accentGlow45;

  /// Warm secondary accent (Chumme's ember): offers, highlights.
  final Color accentWarm;

  /// Full-emphasis text/icons.
  final Color textPrimary;

  /// High-emphasis secondary text.
  final Color textSecondary;

  /// Muted text — timestamps, counters.
  final Color textMuted;

  /// Lowest-emphasis text — de-emphasized labels.
  final Color textSubtle;

  /// Hairline border for cards/dividers.
  final Color border;

  /// Border for focused or emphasized surfaces.
  final Color borderStrong;

  /// The light inner edge of glass surfaces.
  final Color hairline;

  final Color error;
  final Color errorGlow;
  final Color success;
  final Color warning;

  /// Gate Closes dark identity — the primary/default theme.
  static const dark = GateColors(
    background: Color(0xFF120A0D), // maroon950
    backgroundCanvas: Color(0xFF170D10), // maroon900
    surface: Color(0xFF201519), // maroon800
    surfaceElevated: Color(0xFF2A1B20), // maroon700
    surfacePressed: Color(0xFF3A232A), // maroon600
    glass: Color(0x8C2A1B20), // maroon700 @ 55%
    glassStrong: Color(0xBD2E1D23), // maroon650 @ 74%
    accent: Color(0xFFBBE40A),
    accentOn: Color(0xFF000000),
    accentGlow15: Color(0x26BBE40A),
    accentGlow20: Color(0x33BBE40A),
    accentGlow45: Color(0x73BBE40A),
    accentWarm: Color(0xFFFF7A45), // ember500
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFCDC0C5), // fog300
    textMuted: Color(0xFFA8969D), // fog500
    textSubtle: Color(0xFF786870), // fog700
    border: Color(0x14F4EEF0), // fog100 @ 8%
    borderStrong: Color(0x29F4EEF0), // fog100 @ 16%
    hairline: Color(0x1AFFFFFF), // white @ 10%
    error: Color(0xFFE14B4B), // coral500
    errorGlow: Color(0x26E14B4B),
    success: Color(0xFF10B981), // mint500
    warning: Color(0xFFFBBF24), // gold400
  );

  /// Gate Closes light identity — keeps the lime hue (darkened for contrast
  /// on white), not a straight inversion of [dark].
  static const light = GateColors(
    background: Color(0xFFF7F8F4),
    backgroundCanvas: Color(0xFFF0F2EC),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfacePressed: Color(0xFFE9EBE4),
    glass: Color(0xB3FFFFFF),
    glassStrong: Color(0xE6FFFFFF),
    accent: Color(0xFF8FB800),
    accentOn: Color(0xFF000000),
    accentGlow15: Color(0x268FB800),
    accentGlow20: Color(0x338FB800),
    accentGlow45: Color(0x738FB800),
    accentWarm: Color(0xFFE8641F),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF333333),
    textMuted: Color(0xFF666666),
    textSubtle: Color(0xFF888888),
    border: Color(0x14111111),
    borderStrong: Color(0x29111111),
    hairline: Color(0x14111111),
    error: Color(0xFFDC2626),
    errorGlow: Color(0x26DC2626),
    success: Color(0xFF2FA36B),
    warning: Color(0xFFD89614),
  );

  @override
  GateColors copyWith({
    Color? background,
    Color? backgroundCanvas,
    Color? surface,
    Color? surfaceElevated,
    Color? surfacePressed,
    Color? glass,
    Color? glassStrong,
    Color? accent,
    Color? accentOn,
    Color? accentGlow15,
    Color? accentGlow20,
    Color? accentGlow45,
    Color? accentWarm,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textSubtle,
    Color? border,
    Color? borderStrong,
    Color? hairline,
    Color? error,
    Color? errorGlow,
    Color? success,
    Color? warning,
  }) {
    return GateColors(
      background: background ?? this.background,
      backgroundCanvas: backgroundCanvas ?? this.backgroundCanvas,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfacePressed: surfacePressed ?? this.surfacePressed,
      glass: glass ?? this.glass,
      glassStrong: glassStrong ?? this.glassStrong,
      accent: accent ?? this.accent,
      accentOn: accentOn ?? this.accentOn,
      accentGlow15: accentGlow15 ?? this.accentGlow15,
      accentGlow20: accentGlow20 ?? this.accentGlow20,
      accentGlow45: accentGlow45 ?? this.accentGlow45,
      accentWarm: accentWarm ?? this.accentWarm,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      hairline: hairline ?? this.hairline,
      error: error ?? this.error,
      errorGlow: errorGlow ?? this.errorGlow,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  GateColors lerp(ThemeExtension<GateColors>? other, double t) {
    if (other is! GateColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return GateColors(
      background: mix(background, other.background),
      backgroundCanvas: mix(backgroundCanvas, other.backgroundCanvas),
      surface: mix(surface, other.surface),
      surfaceElevated: mix(surfaceElevated, other.surfaceElevated),
      surfacePressed: mix(surfacePressed, other.surfacePressed),
      glass: mix(glass, other.glass),
      glassStrong: mix(glassStrong, other.glassStrong),
      accent: mix(accent, other.accent),
      accentOn: mix(accentOn, other.accentOn),
      accentGlow15: mix(accentGlow15, other.accentGlow15),
      accentGlow20: mix(accentGlow20, other.accentGlow20),
      accentGlow45: mix(accentGlow45, other.accentGlow45),
      accentWarm: mix(accentWarm, other.accentWarm),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      textSubtle: mix(textSubtle, other.textSubtle),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      hairline: mix(hairline, other.hairline),
      error: mix(error, other.error),
      errorGlow: mix(errorGlow, other.errorGlow),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
    );
  }
}
