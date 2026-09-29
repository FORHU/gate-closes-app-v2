import 'package:flutter/material.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/radius.dart';

class AppCardTheme {
  AppCardTheme._();

  static CardThemeData build(GateColors colors) => CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: colors.border),
        ),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      );
}
