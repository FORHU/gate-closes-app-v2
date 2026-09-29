import 'package:flutter/material.dart';

/// Design tokens — corner radii.
class AppRadius {
  AppRadius._();

  /// Small radius (buttons, small components) — 12.
  static const sm = 12.0;

  /// Medium radius (input fields, small cards) — 16.
  static const md = 16.0;

  /// Large radius (larger cards) — 20.
  static const lg = 20.0;

  /// Card radius (default for card components) — 24.
  static const card = 24.0;

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
