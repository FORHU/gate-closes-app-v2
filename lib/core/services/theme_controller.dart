import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/services/storage_service.dart';

const _themeModeKey = 'theme_mode';

/// Persisted [ThemeMode] preference, owned by Riverpod (no static mutable
/// theme state). Defaults to dark — Gate Closes' primary identity.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.read(storageServiceProvider).getString(_themeModeKey);
    return switch (stored) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(storageServiceProvider).setString(_themeModeKey, mode.name);
  }

  Future<void> toggle() =>
      setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
