import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/notifications/notification_preferences.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/signed_in_auth.dart';

class _MockRepo extends Mock implements NotificationPreferencesRepository {}

class _SignedOut extends AuthController {
  @override
  AuthState build() => const AuthState();
}

void main() {
  late _MockRepo repo;

  setUpAll(() => registerFallbackValue(NotificationKind.messages));
  setUp(() => repo = _MockRepo());

  ProviderContainer container({bool signedIn = true}) {
    final c = ProviderContainer(
      overrides: [
        if (signedIn)
          signedInAuthOverride
        else
          authControllerProvider.overrideWith(_SignedOut.new),
        notificationPreferencesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('NotificationPreferences.fromJson treats anything but false as on', () {
    expect(
      NotificationPreferences.fromJson(const {'matches': false}),
      const NotificationPreferences(matches: false),
    );
  });

  test('signed out: everything on, nothing loaded', () {
    final c = container(signedIn: false);
    expect(
      c.read(notificationPreferencesProvider),
      const NotificationPreferencesState(),
    );
    verifyNever(() => repo.get());
  });

  test('signed in: loads the saved settings', () async {
    when(() => repo.get()).thenAnswer(
      (_) async => const Right(NotificationPreferences(echoActivity: false)),
    );
    final c = container();
    expect(c.read(notificationPreferencesProvider).isLoading, isTrue);

    await pumpEventQueue();

    final state = c.read(notificationPreferencesProvider);
    expect(state.isLoading, isFalse);
    expect(state.preferences.echoActivity, isFalse);
    expect(state.preferences.messages, isTrue);
  });

  test('a change shows at once and is saved', () async {
    when(() => repo.get())
        .thenAnswer((_) async => const Right(NotificationPreferences()));
    when(() => repo.set(NotificationKind.matches, on: false)).thenAnswer(
      (_) async => const Right(NotificationPreferences(matches: false)),
    );
    final c = container();
    await pumpEventQueue();

    final pending = c
        .read(notificationPreferencesProvider.notifier)
        .set(NotificationKind.matches, on: false);
    expect(c.read(notificationPreferencesProvider).preferences.matches, false);
    expect(await pending, isNull);
    expect(c.read(notificationPreferencesProvider).preferences.matches, false);
  });

  test('a failed save puts the old value back and returns the error', () async {
    when(() => repo.get())
        .thenAnswer((_) async => const Right(NotificationPreferences()));
    when(() => repo.set(any(), on: any(named: 'on'))).thenAnswer(
      (_) async => const Left(ServerFailure('offline')),
    );
    final c = container();
    await pumpEventQueue();

    final error = await c
        .read(notificationPreferencesProvider.notifier)
        .set(NotificationKind.messages, on: false);

    expect(error, 'offline');
    final state = c.read(notificationPreferencesProvider);
    expect(state.preferences.messages, isTrue);
    expect(state.error, 'offline');
  });
}
