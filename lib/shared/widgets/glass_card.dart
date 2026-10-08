import 'package:flutter/material.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/theme/tokens/effects.dart';
import 'package:gate_closes/theme/tokens/radius.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// A floating, softly-shadowed surface — the base for most cards. Chumme's
/// `GlassSurface`: a deep shadow outside, a light hairline edge, a faint
/// gloss across the top-left and, with [holo], a brand stripe on top and a
/// brand glow underneath.
///
/// Set [blur] to true for true glassmorphism over varied content (use
/// sparingly in long lists for performance). When false it renders a solid
/// surface with the same edge and gloss.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadius.card,
    this.blur = false,
    this.holo = false,
    this.onTap,
    this.color,
    this.border = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blur;

  /// Highlights the card: brand stripe along the top, brand glow below.
  final bool holo;
  final VoidCallback? onTap;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final colors = context.colors;
    final surface = color ?? (blur ? colors.glass : colors.surface);

    Widget body = Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              gradient: AppEffects.cardSheen,
            ),
          ),
        ),
        if (holo)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 3,
            child: ColoredBox(color: colors.accent),
          ),
        Padding(padding: padding, child: child),
      ],
    );

    if (blur) {
      body = BackdropFilter(filter: AppEffects.glassFilter, child: body);
    }

    if (onTap != null) {
      body = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, child: body),
      );
    }

    // The shadow sits outside the clip so it isn't cut off; the hairline
    // is drawn over the clipped content so it stays crisp on top of it.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          ...AppEffects.cardShadow,
          if (holo) ...AppEffects.premiumGlow(colors.accent),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: border ? Border.all(color: colors.hairline) : null,
          ),
          child: body,
        ),
      ),
    );
  }
}
