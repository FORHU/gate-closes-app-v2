import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:gate_closes/features/flight/domain/repositories/flight_repository.dart';
import 'package:gate_closes/features/flight/presentation/controllers/flight_controller.dart';
import 'package:gate_closes/features/profile/data/repositories/profile_repository.dart';
import 'package:gate_closes/features/profile/domain/entities/profile_entity.dart';
import 'package:gate_closes/features/profile/presentation/controllers/profile_controller.dart';
import 'package:gate_closes/features/profile/presentation/pages/profile_page.dart';
import 'package:gate_closes/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockFlightRepository extends Mock implements FlightRepository {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockProfileRepository mockProfileRepository;
  late MockFlightRepository mockFlightRepository;
  late MockStorageService mockStorage;

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    mockFlightRepository = MockFlightRepository();
    mockStorage = MockStorageService();

    when(mockStorage.readUserModel).thenReturn(null);
  });

  testWidgets(
    'ProfilePage renders hero and Add Boarding Pass button '
    'when no active flight',
    (tester) async {
      when(mockProfileRepository.getProfile).thenAnswer(
        (_) async => const Right(
          ProfileEntity(
            id: '1',
            name: 'Ada Lovelace',
            email: 'ada@example.com',
            bio: 'Building great things with Flutter.',
          ),
        ),
      );
      when(mockFlightRepository.getActiveFlightTicket).thenAnswer(
        (_) async => const Right(null),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
            profileRepositoryProvider.overrideWithValue(mockProfileRepository),
            flightRepositoryProvider.overrideWithValue(mockFlightRepository),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('FLIGHT DATA'), findsOneWidget);
      expect(find.text('ADD BOARDING PASS'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('GENERAL'), findsOneWidget);
      expect(find.text('Dark mode'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ProfilePage renders active flight card when flight ticket exists',
    (tester) async {
      when(mockProfileRepository.getProfile).thenAnswer(
        (_) async => const Right(
          ProfileEntity(
            id: '1',
            name: 'Ada Lovelace',
            email: 'ada@example.com',
          ),
        ),
      );
      when(mockFlightRepository.getActiveFlightTicket).thenAnswer(
        (_) async => Right(
          FlightTicketEntity(
            id: 'flight-1',
            userId: 'user-1',
            flightNumber: 'SQ321',
            fromAirport: 'SIN',
            toAirport: 'LHR',
            departureDateTime: DateTime(2026, 10, 15, 9, 30),
            returnDateTime: DateTime(2026, 10, 25, 18),
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
            profileRepositoryProvider.overrideWithValue(mockProfileRepository),
            flightRepositoryProvider.overrideWithValue(mockFlightRepository),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SQ321'), findsOneWidget);
      expect(find.text('SIN'), findsWidgets);
      expect(find.text('LHR'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
