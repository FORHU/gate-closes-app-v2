import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/notifications/app_notification.dart';

Map<String, dynamic> _payload({String kind = 'messages', String? route}) => {
      'kind': kind,
      'title': 'New Parallel Soul conversation',
      'body': 'alice started a conversation with you',
      'tag': 'conversation-c1',
      'route': route ?? '/connections/c/0b7c-11ef',
    };

void main() {
  group('AppNotification.fromJson', () {
    test('reads a server payload into the matching channel', () {
      final n = AppNotification.fromJson(_payload())!;
      expect(n.channel, NotificationChannelKind.messages);
      expect(n.route, '/connections/c/0b7c-11ef');
      expect(
        AppNotification.fromJson(_payload(kind: 'matches'))!.channel,
        NotificationChannelKind.matches,
      );
      expect(
        AppNotification.fromJson(_payload(kind: 'echoActivity'))!.channel,
        NotificationChannelKind.echoActivity,
      );
    });

    test('drops payloads missing a field', () {
      expect(AppNotification.fromJson({..._payload(), 'title': null}), isNull);
      expect(AppNotification.fromJson({..._payload()}..remove('tag')), isNull);
    });

    test('only opens the screens notifications are for', () {
      for (final ok in [
        '/',
        '/connections/c/abc-123',
        '/feed/thread/abc-123',
        '/map/echo/abc-123?type=parallel_soul',
      ]) {
        expect(AppNotification.fromJson(_payload(route: ok)), isNotNull);
      }
      for (final bad in [
        'https://evil.test/connections/c/1',
        '//evil.test/x',
        '/profile/change-password',
        '/connections/c/../../profile',
        '',
      ]) {
        expect(
          AppNotification.fromJson(_payload(route: bad)),
          isNull,
          reason: bad,
        );
      }
    });
  });

  test('a tag maps to the same notification id every run', () {
    // Pinned (cross-checked with the same FNV-1a in Python) so a change
    // to the hash, which would orphan notifications already shown, fails.
    expect(notificationIdFor('conversation-c1'), 1139617253);
    expect(
      notificationIdFor('conversation-c1'),
      isNot(notificationIdFor('conversation-c2')),
    );
    expect(notificationIdFor('x'), inInclusiveRange(0, 0x7fffffff));
  });
}
