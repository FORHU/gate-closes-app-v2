import 'package:flutter/material.dart';
import 'package:flutter_template/theme/dark_theme.dart';
import 'package:flutter_template/theme/light_theme.dart';

/// The central Theme configuration for the application.
class AppTheme {
  AppTheme._();

  static ThemeData get light => LightTheme.build();
  static ThemeData get dark => DarkTheme.build();
}
