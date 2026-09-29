import 'package:flutter/material.dart';
import 'package:gate_closes/theme/dark_theme.dart';
import 'package:gate_closes/theme/light_theme.dart';

/// The central Theme configuration for the application.
class AppTheme {
  AppTheme._();

  static ThemeData get light => LightTheme.build();
  static ThemeData get dark => DarkTheme.build();
}
