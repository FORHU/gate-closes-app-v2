import 'package:flutter/material.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/theme/tokens/effects.dart';
import 'package:flutter_template/theme/tokens/radius.dart';
import 'package:flutter_template/theme/tokens/spacing.dart';

/// A floating, softly-shadowed surface — the base for most cards.
///
/// Set [blur] to true for true glassmorphism (use sparingly in long lists for
/// performance). When false it renders a solid premium surface.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadius.card,
    this.blur = false,
    this.onTap,
    this.color,
    this.border = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blur;
  final VoidCallback? onTap;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final gateColors = context.colors;
    final surface = color ??
        (blur ? gateColors.surface.withValues(alpha: 0.6) : gateColors.surface);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: borderRadius,
        border: border ? Border.all(color: gateColors.border) : null,
        boxShadow: AppEffects.cardShadow,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (blur) {
      content = BackdropFilter(filter: AppEffects.glassFilter, child: content);
    }

    content = ClipRRect(borderRadius: borderRadius, child: content);

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
    );
  }
}
