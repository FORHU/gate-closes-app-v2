import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/notifications/app_notification.dart';
import 'package:gate_closes/core/notifications/local_notification_service.dart';

const _notification = AppNotification(
  channel: NotificationChannelKind.messages,
  title: 'Parallel Soul',
  body: 'alice sent you a voice message',
  tag: 'conversation-c1',
  route: '/connections/c/c1',
);

/// The plugin is never initialised here, so `show` is a no-op: what matters
/// is which way `deliver` sends each notification.
LocalNotificationService _service(AppLifecycleState? state) =>
    LocalNotificationService(lifecycleState: () => state);

void main() {
  test('on screen with a banner host: in-app banner, not the panel', () async {
    final service = _service(AppLifecycleState.resumed);
    final banners = <AppNotification>[];
    final sub = service.inApp.listen(banners.add);
    addTearDown(sub.cancel);

    expect(service.deliver(_notification), NotificationDisplay.inApp);
    await pumpEventQueue();
    expect(banners, [_notification]);
  });

  test('not on screen: the notification panel, never a banner', () async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
      null,
    ]) {
      final service = _service(state);
      final banners = <AppNotification>[];
      final sub = service.inApp.listen(banners.add);

      expect(
        service.deliver(_notification),
        NotificationDisplay.system,
        reason: '$state',
      );
      await pumpEventQueue();
      expect(banners, isEmpty, reason: '$state');
      await sub.cancel();
    }
  });

  test('on screen but nothing hosts banners yet: the panel, so none is lost',
      () {
    expect(
      _service(AppLifecycleState.resumed).deliver(_notification),
      NotificationDisplay.system,
    );
  });
}
