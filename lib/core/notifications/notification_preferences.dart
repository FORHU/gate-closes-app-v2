import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';

/// What a user can turn on or off in Settings → Notifications. [apiKey] is
/// the field name in `/notifications/preferences`.
enum NotificationKind {
  messages('messages'),
  echoActivity('echoActivity'),
  matches('matches'),
  flightReminders('flightReminders');

  const NotificationKind(this.apiKey);

  final String apiKey;
}

/// Every kind is on until the user turns it off (the server's default too).
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.messages = true,
    this.echoActivity = true,
    this.matches = true,
    this.flightReminders = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    bool read(NotificationKind kind) => json[kind.apiKey] != false;
    return NotificationPreferences(
      messages: read(NotificationKind.messages),
      echoActivity: read(NotificationKind.echoActivity),
      matches: read(NotificationKind.matches),
      flightReminders: read(NotificationKind.flightReminders),
    );
  }

  final bool messages;
  final bool echoActivity;
  final bool matches;
  final bool flightReminders;

  bool isOn(NotificationKind kind) => switch (kind) {
        NotificationKind.messages => messages,
        NotificationKind.echoActivity => echoActivity,
        NotificationKind.matches => matches,
        NotificationKind.flightReminders => flightReminders,
      };

  NotificationPreferences withKind(NotificationKind kind, {required bool on}) =>
      NotificationPreferences(
        messages: kind == NotificationKind.messages ? on : messages,
        echoActivity: kind == NotificationKind.echoActivity ? on : echoActivity,
        matches: kind == NotificationKind.matches ? on : matches,
        flightReminders:
            kind == NotificationKind.flightReminders ? on : flightReminders,
      );

  @override
  List<Object?> get props => [messages, echoActivity, matches, flightReminders];
}

class NotificationPreferencesRepository {
  const NotificationPreferencesRepository(this._api);

  final ApiService _api;

  Future<Either<Failure, NotificationPreferences>> get() =>
      _call(() => _api.get(ApiEndpoints.notificationPreferences));

  Future<Either<Failure, NotificationPreferences>> set(
    NotificationKind kind, {
    required bool on,
  }) =>
      _call(
        () => _api.patch(ApiEndpoints.notificationPreferences, {
          kind.apiKey: on,
        }),
      );

  Future<Either<Failure, NotificationPreferences>> _call(
    Future<dynamic> Function() request,
  ) async {
    try {
      final response = await request();
      final data = (response as Map)['data'];
      if (data is! Map) {
        return const Left(ServerFailure('Unexpected notification settings.'));
      }
      return Right(NotificationPreferences.fromJson(data.cast()));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>(
  (ref) => NotificationPreferencesRepository(ref.watch(apiServiceProvider)),
);

class NotificationPreferencesState extends Equatable {
  const NotificationPreferencesState({
    this.preferences = const NotificationPreferences(),
    this.isLoading = false,
    this.error,
  });

  final NotificationPreferences preferences;
  final bool isLoading;
  final String? error;

  @override
  List<Object?> get props => [preferences, isLoading, error];
}

/// The signed-in user's notification settings. Loads on sign-in; until then
/// (and offline) everything counts as on, the same default as the server.
class NotificationPreferencesController
    extends Notifier<NotificationPreferencesState> {
  @override
  NotificationPreferencesState build() {
    final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    if (userId == null) return const NotificationPreferencesState();
    unawaited(Future.microtask(load));
    return const NotificationPreferencesState(isLoading: true);
  }

  Future<void> load() async {
    final result =
        await ref.read(notificationPreferencesRepositoryProvider).get();
    if (!ref.mounted) return;
    state = result.fold(
      (failure) => NotificationPreferencesState(
        preferences: state.preferences,
        error: failure.message,
      ),
      (preferences) => NotificationPreferencesState(preferences: preferences),
    );
  }

  /// Flips one kind right away, then saves it; on failure the old value
  /// comes back and the error is returned.
  Future<String?> set(NotificationKind kind, {required bool on}) async {
    final previous = state.preferences;
    state = NotificationPreferencesState(
      preferences: previous.withKind(kind, on: on),
    );
    final result = await ref
        .read(notificationPreferencesRepositoryProvider)
        .set(kind, on: on);
    if (!ref.mounted) return null;
    return result.fold(
      (failure) {
        state = NotificationPreferencesState(
          preferences: previous,
          error: failure.message,
        );
        return failure.message;
      },
      (saved) {
        state = NotificationPreferencesState(preferences: saved);
        return null;
      },
    );
  }
}

final notificationPreferencesProvider = NotifierProvider<
    NotificationPreferencesController, NotificationPreferencesState>(
  NotificationPreferencesController.new,
);
