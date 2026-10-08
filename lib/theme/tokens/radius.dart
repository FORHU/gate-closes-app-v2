import 'package:flutter/material.dart';

/// Design tokens — corner radii, on Chumme's tighter scale.
class AppRadius {
  AppRadius._();

  /// Small radius (buttons, small components) — 10.
  static const sm = 10.0;

  /// Medium radius (input fields, small cards) — 16.
  static const md = 16.0;

  /// Large radius (larger cards) — 22.
  static const lg = 22.0;

  /// Card radius (default for card components, Chumme glass panels) — 16.
  static const card = 16.0;

  /// Extra-large radius (hero panels, sheets) — 28.
  static const xl = 28.0;

  /// Fully rounded (pills, chips, FABs) — 999.
  static const pill = 999.0;

  // Convenience BorderRadius getters.
  static BorderRadius get brSm => BorderRadius.circular(sm);
  static BorderRadius get brMd => BorderRadius.circular(md);
  static BorderRadius get brLg => BorderRadius.circular(lg);
  static BorderRadius get brCard => BorderRadius.circular(card);
  static BorderRadius get brXl => BorderRadius.circular(xl);
  static BorderRadius get brPill => BorderRadius.circular(pill);
}
