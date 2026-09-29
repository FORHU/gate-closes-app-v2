import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const xxxl = 72.0;

  // Paddings
  static const EdgeInsets edgeInsetsXs = EdgeInsets.all(xs);
  static const EdgeInsets edgeInsetsSm = EdgeInsets.all(sm);
  static const EdgeInsets edgeInsetsMd = EdgeInsets.all(md);
  static const EdgeInsets edgeInsetsLg = EdgeInsets.all(lg);
  static const EdgeInsets edgeInsetsXl = EdgeInsets.all(xl);

  static Widget h(double value) => SizedBox(width: value);
  static Widget v(double value) => SizedBox(height: value);

  static Widget get hSm => h(sm);
  static Widget get vSm => v(sm);
  static Widget get vMd => v(md);
}

extension SpaceX on num {
  /// Returns a horizontal SizedBox of `this` width.
  Widget get h => SizedBox(width: toDouble());

  /// Returns a vertical SizedBox of `this` height.
  Widget get v => SizedBox(height: toDouble());
}
