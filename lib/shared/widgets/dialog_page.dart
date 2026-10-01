import 'package:flutter/material.dart';

/// A go_router page that shows [child] as a modal dialog over the current
/// screen (dimmed barrier, tap outside to dismiss) instead of a full page.
class DialogPage<T> extends Page<T> {
  const DialogPage({required this.child, super.key});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => DialogRoute<T>(
        context: context,
        settings: this,
        builder: (_) => child,
      );
}
