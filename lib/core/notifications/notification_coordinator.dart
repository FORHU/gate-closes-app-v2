import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/notifications/app_notification.dart';
import 'package:gate_closes/core/notifications/flight_reminder.dart';
import 'package:gate_closes/core/notifications/local_notification_service.dart';
import 'package:gate_closes/core/notifications/notification_preferences.dart';
import 'package:gate_closes/core/services/authenticated_socket.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/flight/presentation/controllers/flight_controller.dart';

/// Everything notifications need while someone is signed in; watched by the
/// app, rebuilt on every sign-in and torn down on sign-out.
///
/// * One `/notifications` socket: the API decides who is told what (and
///   honours the user's settings); this shows it. Phase 1 has no push, so
///   these only arrive while the app is running.
/// * The flight reminder follows the active ticket and the setting.
final notificationCoordinatorProvider = Provider<void>((ref) {
  final service = ref.watch(localNotificationServiceProvider);
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) {
    unawaited(service.setFlightReminder(null));
    return;
  }

  final socket = AuthenticatedSocket(
    namespace: '/notifications',
    authKey: 'accessToken',
    readToken: ref.read(storageServiceProvider).readToken,
    revalidateSession: () =>
        ref.read(authControllerProvider.notifier).refreshAuth(),
  );
  socket.socket.on('notification', (data) {
    if (data is! Map) return;
    final notification = AppNotification.fromJson(data.cast<String, dynamic>());
    // Banner while the app is on screen, notification panel otherwise.
    if (notification != null) service.deliver(notification);
  });
  ref.onDispose(socket.close);

  void syncReminder() {
    final ticket = ref.read(flightControllerProvider).activeFlight;
    if (ticket == null) return;
    final enabled =
        ref.read(notificationPreferencesProvider).preferences.flightReminders;
    unawaited(
      service.setFlightReminder(
        planFlightReminder(ticket, enabled: enabled, now: DateTime.now()),
      ),
    );
  }

  ref
    ..listen(flightControllerProvider, (previous, next) {
      if (next.activeFlight != null) return syncReminder();
      // Gone after a successful load or a delete (not a failed reload).
      final removed = previous?.activeFlight != null &&
          !next.isLoading &&
          next.error == null;
      if (removed) unawaited(service.setFlightReminder(null));
    })
    ..listen(
      notificationPreferencesProvider.select(
        (s) => s.preferences.flightReminders,
      ),
      (_, enabled) =>
          enabled ? syncReminder() : unawaited(service.setFlightReminder(null)),
    );

  // Settings normally loads the ticket; reminders need it from the start.
  unawaited(
    Future.microtask(
      () => ref.read(flightControllerProvider.notifier).fetchActiveFlight(),
    ),
  );

  // Returning users are asked here; new ones when onboarding finishes.
  final storage = ref.read(storageServiceProvider);
  if (storage.isOnboardingSeen(userId)) {
    unawaited(askNotificationPermissionOnce(storage, service));
  }
});

/// Shows the system prompt the first time only; afterwards the user can
/// allow notifications from Settings → Notifications.
Future<void> askNotificationPermissionOnce(
  StorageService storage,
  LocalNotificationService service,
) async {
  if (!service.isReady || storage.notificationPermissionAsked) return;
  await storage.setNotificationPermissionAsked();
  await service.requestPermission();
}
