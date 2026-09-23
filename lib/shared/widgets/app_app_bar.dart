import 'package:flutter/material.dart';

/// A reusable, standardized AppBar for the application.
/// It implements [PreferredSizeWidget] so it can be used directly in the
/// `Scaffold.appBar` slot.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    required this.titleText,
    super.key,
    this.actions,
    this.leading,
    this.centerTitle = true,
  });

  /// The text to display in the title slot.
  final String titleText;

  /// Optional list of widgets to display at the right side of the app bar.
  final List<Widget>? actions;

  /// Optional widget to display at the left side of the app bar (e.g., a
  /// custom back button).
  final Widget? leading;

  /// Whether the title should be centered. Defaults to true.
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(titleText),
      centerTitle: centerTitle,
      actions: actions,
      leading: leading,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
