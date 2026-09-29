import 'package:flutter/material.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/shared/widgets/buttons.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:gap/gap.dart';

/// Visual intent for [AppStateView]. Drives the default icon and accent color.
enum AppStateKind { error, empty, notFound, info }

/// A centered full-bleed placeholder for empty / error / not-found states.
///
/// Use it wherever a screen has no content to show — a failed load, an empty
/// list, an unsupported platform, etc. Provide a [title] and [message]; pass
/// [actionLabel] + [onAction] to render a retry / CTA button.
///
/// ```dart
/// AppStateView(
///   kind: AppStateKind.error,
///   title: 'Something went wrong',
///   message: 'We couldn\'t load the data. Please try again.',
///   actionLabel: 'Retry',
///   onAction: _reload,
/// )
/// ```
class AppStateView extends StatelessWidget {
  const AppStateView({
    required this.title,
    this.message,
    this.kind = AppStateKind.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Headline summarising the state.
  final String title;

  /// Optional supporting line(s) under the title.
  final String? message;

  /// Visual intent — selects the default icon and accent color.
  final AppStateKind kind;

  /// Override the default icon for [kind].
  final IconData? icon;

  /// Label for the optional action button. Requires [onAction] to render.
  final String? actionLabel;

  /// Tapped when the action button is pressed.
  final VoidCallback? onAction;

  IconData get _icon => icon ?? _defaultIconFor(kind);

  Color _accentFor(GateColors colors) => switch (kind) {
        AppStateKind.error => colors.error,
        AppStateKind.empty => colors.textMuted,
        AppStateKind.notFound => colors.accent,
        AppStateKind.info => colors.accent,
      };

  static IconData _defaultIconFor(AppStateKind kind) => switch (kind) {
        AppStateKind.error => Icons.error_outline_rounded,
        AppStateKind.empty => Icons.inbox_outlined,
        AppStateKind.notFound => Icons.search_off_rounded,
        AppStateKind.info => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;
    final colors = context.colors;
    final accent = _accentFor(colors);

    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.edgeInsetsLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.30)),
              ),
              child: Icon(_icon, size: 36, color: accent),
            ),
            const Gap(AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const Gap(AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            if (hasAction) ...[
              const Gap(AppSpacing.xl),
              PrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
