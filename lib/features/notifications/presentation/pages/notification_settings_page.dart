import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/notifications/local_notification_service.dart';
import 'package:gate_closes/core/notifications/notification_preferences.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/shared/widgets/top_toast.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// Settings → Notifications: one switch per kind, saved to the account, and
/// a banner while the phone itself blocks notifications.
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  static const Map<NotificationKind, (String, String)> _kinds = {
    NotificationKind.messages: (
      'Messages',
      'When a traveler starts a conversation or sends you a message.',
    ),
    NotificationKind.echoActivity: (
      'Echo activity',
      'Replies and reactions on your echoes.',
    ),
    NotificationKind.matches: (
      'Matches nearby',
      'A Parallel Soul, Destination Thread or Baton Touch traveler posts at '
          'an airport on your flight.',
    ),
    NotificationKind.flightReminders: (
      'Flight reminders',
      'Three hours before your saved flight departs.',
    ),
  };

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage>
    with WidgetsBindingObserver {
  /// Null until checked.
  bool? _systemAllowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkSystemPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check when the user comes back from the phone's settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkSystemPermission());
    }
  }

  Future<void> _checkSystemPermission() async {
    final allowed =
        await ref.read(localNotificationServiceProvider).areEnabled();
    if (mounted) setState(() => _systemAllowed = allowed);
  }

  Future<void> _allow() async {
    final service = ref.read(localNotificationServiceProvider);
    final granted = await service.requestPermission();
    await _checkSystemPermission();
    if (!granted && mounted && _systemAllowed == false) {
      showTopToast(
        context,
        'Turn on notifications for Gate Closes in your phone settings.',
      );
    }
  }

  Future<void> _toggle(NotificationKind kind, bool on) async {
    final error = await ref
        .read(notificationPreferencesProvider.notifier)
        .set(kind, on: on);
    if (error != null && mounted) {
      showTopToast(context, "Couldn't save that change. $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: const Text('Notifications'),
      ),
      body: ListView(
        padding: AppSpacing.edgeInsetsMd,
        children: [
          if (_systemAllowed == false) ...[
            _PermissionBanner(onAllow: () => unawaited(_allow())),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            'For now these arrive while Gate Closes is open or was used '
            'recently. Flight reminders arrive even when it is closed.',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final MapEntry(key: kind, value: (title, description))
                in NotificationSettingsPage._kinds.entries)
              _KindTile(
                title: title,
                description: description,
                on: state.preferences.isOn(kind),
                onChanged: (on) => unawaited(_toggle(kind, on)),
              ),
          if (state.error != null && !state.isLoading)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                "Couldn't load your settings, so everything shows as on. "
                'Changes still save when you are online.',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.accent),
      ),
      child: Padding(
        padding: AppSpacing.edgeInsetsMd,
        child: Row(
          children: [
            Icon(Icons.notifications_off_outlined, color: colors.accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Notifications are turned off for Gate Closes on this phone.',
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(onPressed: onAllow, child: const Text('Allow')),
          ],
        ),
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.title,
    required this.description,
    required this.on,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.border),
        ),
        child: SwitchListTile(
          value: on,
          onChanged: onChanged,
          activeTrackColor: colors.accent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            description,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
