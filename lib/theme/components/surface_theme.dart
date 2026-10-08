import 'package:flutter/material.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/radius.dart';

/// Raised surfaces in the Chumme style: sheets and dialogs one layer up from
/// the cards, edged with the glass hairline; flat dividers in the border tone.
class AppSurfaceTheme {
  AppSurfaceTheme._();

  static BottomSheetThemeData bottomSheet(GateColors colors) =>
      BottomSheetThemeData(
        backgroundColor: colors.surfaceElevated,
        modalBackgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.6),
        dragHandleColor: colors.borderStrong,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          side: BorderSide(color: colors.hairline),
        ),
      );

  static DialogThemeData dialog(GateColors colors) => DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brLg,
          side: BorderSide(color: colors.hairline),
        ),
      );

  static SnackBarThemeData snackBar(GateColors colors) => SnackBarThemeData(
        backgroundColor: colors.surfacePressed,
        contentTextStyle: TextStyle(color: colors.textPrimary),
        actionTextColor: colors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
          side: BorderSide(color: colors.hairline),
        ),
      );

  static DividerThemeData divider(GateColors colors) =>
      DividerThemeData(color: colors.border, thickness: 1, space: 1);
}
