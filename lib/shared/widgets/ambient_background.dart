import 'package:flutter/material.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';

/// Ambient backdrop, pure Flutter (`RadialGradient`s — no package): Chumme's
/// `AmbientBackground`, two soft brand blooms over the app background — a
/// larger one off the top-left corner and a fainter one off the top-right.
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
    // Radii are fractions of the shortest side (the width on a phone);
    // the stops end each bloom about halfway out, as Chumme's do.
    RadialGradient bloom(
      Alignment center,
      double radius,
      double alpha,
      double fadeAt,
    ) =>
        RadialGradient(
          center: center,
          radius: radius,
          colors: [
            colors.accent.withValues(alpha: alpha),
            colors.accent.withValues(alpha: 0),
          ],
          stops: [0, fadeAt],
        );

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.background),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: bloom(const Alignment(-0.7, -1.1), 1.6, 0.14, 0.5),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: bloom(const Alignment(1, -0.84), 1.4, 0.1, 0.55),
          ),
          child: child,
        ),
      ),
    );
  }
}
