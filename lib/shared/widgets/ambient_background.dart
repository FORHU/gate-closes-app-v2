import 'package:flutter/material.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';

/// Ambient accent-glow backdrop, pure Flutter (`RadialGradient` on a
/// `Container` — no package). Ported from `gate-closes-app`'s
/// `AnimatedRadialGradient`/`GradientBackground`.
///
/// Without this, translucent glass surfaces (`GlassCard`) blur a flat solid
/// background and look identical to an opaque surface — there's nothing
/// varied behind them to blur. Wrap a screen's body in this to give glass
/// surfaces something to actually read as "glass" against.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        gradient: RadialGradient(
          center: const Alignment(0.6, -0.9),
          radius: 1.2,
          colors: [colors.accentGlow15, colors.background],
          stops: const [0, 0.6],
        ),
      ),
      child: child,
    );
  }
}
