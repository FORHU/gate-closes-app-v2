import 'package:equatable/equatable.dart';

/// Android notification channels, one per kind the user can turn off. Their
/// ids are permanent: Android keeps a channel's settings by id.
enum NotificationChannelKind {
  messages(
    'messages',
    'Messages',
    'New messages from travelers you connect with',
  ),
  echoActivity(
    'echo_activity',
    'Echo activity',
    'Replies and reactions on your echoes',
  ),
  matches(
    'matches',
    'Matches nearby',
    'Travelers on matching flights posting near you',
  ),
  flightReminders(
    'flight_reminders',
    'Flight reminders',
    'A reminder before your flight departs',
  );

  const NotificationChannelKind(this.id, this.name, this.description);

  final String id;
  final String name;
  final String description;

  /// The channel for a server payload's `kind` (unknown kinds fall back to
  /// echo activity, the quietest server channel).
  static NotificationChannelKind fromApiKind(String? kind) => switch (kind) {
        'messages' => messages,
        'matches' => matches,
        _ => echoActivity,
      };
}

/// A `notification` event from the API's `/notifications` socket.
class AppNotification extends Equatable {
  const AppNotification({
    required this.channel,
    required this.title,
    required this.body,
    required this.tag,
    required this.route,
  });

  /// Null when the payload is missing something or points somewhere the app
  /// shouldn't open from a notification.
  static AppNotification? fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final body = json['body'];
    final tag = json['tag'];
    final route = json['route'];
    if (title is! String || body is! String || tag is! String) return null;
    if (route is! String || !isNotificationRoute(route)) return null;
    return AppNotification(
      channel: NotificationChannelKind.fromApiKind(json['kind'] as String?),
      title: title,
      body: body,
      tag: tag,
      route: route,
    );
  }

  final NotificationChannelKind channel;
  final String title;
  final String body;

  /// A newer notification with the same tag replaces the older one.
  final String tag;

  /// Where a tap goes.
  final String route;

  /// Stable across app restarts (unlike `String.hashCode`), so a tag keeps
  /// replacing its own notification. 31-bit FNV-1a.
  int get id => notificationIdFor(tag);

  @override
  List<Object?> get props => [channel, title, body, tag, route];
}

int notificationIdFor(String tag) {
  var hash = 0x811c9dc5;
  for (final unit in tag.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

/// Only these screens may be opened from a notification.
bool isNotificationRoute(String route) {
  final uri = Uri.tryParse(route);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return false;
  final path = uri.path;
  return path == '/' ||
      RegExp(r'^/connections/c/[\w-]+$').hasMatch(path) ||
      RegExp(r'^/feed/thread/[\w-]+$').hasMatch(path) ||
      RegExp(r'^/map/echo/[\w-]+$').hasMatch(path);
}
