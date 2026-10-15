import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/notifications/app_notification.dart';
import 'package:gate_closes/core/notifications/flight_reminder.dart';
import 'package:gate_closes/core/utils/logger.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Where [LocalNotificationService.deliver] showed a notification.
enum NotificationDisplay { inApp, system }

/// Shows notifications on the phone, schedules the flight reminder, and
/// reports taps as app routes.
///
/// Does nothing until [init] has run (bootstrap calls it), so widget tests
/// and anything else without the platform plugin stay unaffected.
class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    AppLifecycleState? Function()? lifecycleState,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _lifecycleState =
            lifecycleState ?? (() => WidgetsBinding.instance.lifecycleState);

  /// The one the app uses (the plugin itself is a platform singleton).
  static final LocalNotificationService instance = LocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin;
  final AppLifecycleState? Function() _lifecycleState;
  final _taps = StreamController<String>.broadcast();
  final _inApp = StreamController<AppNotification>.broadcast();
  bool _ready = false;
  String? _launchRoute;

  /// False until [init] succeeds (and always in widget tests).
  bool get isReady => _ready;

  /// Routes of notifications tapped while the app is running.
  Stream<String> get taps => _taps.stream;

  /// Notifications to show as an in-app banner (the app is on screen).
  Stream<AppNotification> get inApp => _inApp.stream;

  /// Shows [notification] in exactly one place: an in-app banner while the
  /// app is on screen and something hosts banners, otherwise the phone's
  /// notification panel.
  NotificationDisplay deliver(AppNotification notification) {
    final onScreen = _lifecycleState() == AppLifecycleState.resumed;
    if (onScreen && _inApp.hasListener) {
      _inApp.add(notification);
      return NotificationDisplay.inApp;
    }
    unawaited(show(notification));
    return NotificationDisplay.system;
  }

  /// The route of the notification that launched the app, once.
  String? takeLaunchRoute() {
    final route = _launchRoute;
    _launchRoute = null;
    return route;
  }

  Future<void> init() async {
    if (_ready) return;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Asked from Settings / after sign-in, not at launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final route = response.payload;
          if (route != null && isNotificationRoute(route)) _taps.add(route);
        },
      );
      final android = _android;
      if (android != null) {
        for (final channel in NotificationChannelKind.values) {
          await android.createNotificationChannel(_channel(channel));
        }
      }
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final route = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) &&
          route != null &&
          isNotificationRoute(route)) {
        _launchRoute = route;
      }
      _ready = true;
    } on Object catch (e) {
      appLogger.w('Notifications unavailable: $e');
    }
  }

  /// Asks for permission (Android 13+ shows the system prompt once).
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      return await _android?.requestNotificationsPermission() ?? false;
    } on Object catch (e) {
      appLogger.w('Notification permission request failed: $e');
      return false;
    }
  }

  /// Whether the user allows notifications at all (system setting).
  Future<bool> areEnabled() async {
    if (!_ready) return false;
    try {
      return await _android?.areNotificationsEnabled() ?? true;
    } on Object {
      return false;
    }
  }

  Future<void> show(AppNotification notification) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        notificationDetails: _details(notification.channel),
        payload: notification.route,
      );
    } on Object catch (e) {
      appLogger.w('Could not show notification: $e');
    }
  }

  /// Replaces any pending flight reminder with [reminder] (none if null).
  Future<void> setFlightReminder(FlightReminder? reminder) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: flightReminderId);
      if (reminder == null) return;
      await _plugin.zonedSchedule(
        id: flightReminderId,
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
        notificationDetails: _details(NotificationChannelKind.flightReminders),
        // Inexact: no exact-alarm permission, and minutes don't matter here.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: reminder.title,
        body: reminder.body,
        payload: '/',
      );
    } on Object catch (e) {
      appLogger.w('Could not schedule the flight reminder: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static AndroidNotificationChannel _channel(NotificationChannelKind kind) =>
      AndroidNotificationChannel(
        kind.id,
        kind.name,
        description: kind.description,
        importance: _importance(kind),
      );

  static Importance _importance(NotificationChannelKind kind) => switch (kind) {
        NotificationChannelKind.messages ||
        NotificationChannelKind.flightReminders =>
          Importance.high,
        _ => Importance.defaultImportance,
      };

  static NotificationDetails _details(NotificationChannelKind kind) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          kind.id,
          kind.name,
          channelDescription: kind.description,
          importance: _importance(kind),
          priority: _importance(kind) == Importance.high
              ? Priority.high
              : Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      );
}

/// The app's instance; bootstrap initialises it before `runApp`. Tests can
/// override the provider with a fake.
final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => LocalNotificationService.instance,
);
