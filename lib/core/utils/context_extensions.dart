import 'package:flutter/material.dart';
import 'package:flutter_template/l10n/generated/app_localizations.dart';
import 'package:flutter_template/theme/tokens/colors.dart';

extension L10nExtension on BuildContext {
  /// Provides clean, non-nullable access to AppLocalizations.
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension GateColorsX on BuildContext {
  /// Theme-aware Gate Closes palette: `context.colors.accent`, etc.
  GateColors get colors =>
      Theme.of(this).extension<GateColors>() ?? GateColors.dark;
}
