import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/errors/failure.dart';
import 'package:flutter_template/features/airport/domain/entities/airport_entity.dart';
import 'package:flutter_template/features/airport/domain/repositories/airport_repository.dart';
import 'package:flutter_template/features/airport/presentation/controllers/airport_controller.dart';
import 'package:flutter_template/features/location/domain/entities/location_coordinates.dart';
import 'package:flutter_template/features/location/domain/repositories/location_repository.dart';
import 'package:flutter_template/features/worldMap/presentation/pages/world_map_page.dart';
import 'package:flutter_template/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockLocationRepository extends Mock implements LocationRepository {}

class MockAirportRepository extends Mock implements AirportRepository {}

const _tCoordinates = LocationCoordinates(latitude: 1.35, longitude: 103.99);

void main() {
  testWidgets(
    'WorldMapPage renders the fetched nearby airports with no layout errors',
    (tester) async {
      final mockLocationRepository = MockLocationRepository();
      final mockAirportRepository = MockAirportRepository();
      when(
        mockLocationRepository.getCurrentLocation,
      ).thenAnswer((_) async => const Right(_tCoordinates));
      when(
        () => mockAirportRepository.findNearby(_tCoordinates),
      ).thenAnswer(
        (_) async => const Right([
          AirportEntity(
            id: 'SIN',
            name: 'Singapore Changi Airport',
            iata: 'SIN',
            distanceKm: 0.8,
          ),
          AirportEntity(
            id: 'JHB',
            name: 'Senai International Airport',
            iata: 'JHB',
            distanceKm: 45.2,
          ),
        ]),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationRepositoryProvider.overrideWithValue(
              mockLocationRepository,
            ),
            airportRepositoryProvider.overrideWithValue(
              mockAirportRepository,
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WorldMapPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Singapore Changi Airport'), findsOneWidget);
      expect(find.text('Senai International Airport'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('WorldMapPage shows an empty state with no results', (
    tester,
  ) async {
    final mockLocationRepository = MockLocationRepository();
    final mockAirportRepository = MockAirportRepository();
    when(
      mockLocationRepository.getCurrentLocation,
    ).thenAnswer((_) async => const Right(_tCoordinates));
    when(
      () => mockAirportRepository.findNearby(_tCoordinates),
    ).thenAnswer((_) async => const Right([]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          airportRepositoryProvider.overrideWithValue(mockAirportRepository),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorldMapPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No nearby airports'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('WorldMapPage shows a retry option when the fetch fails', (
    tester,
  ) async {
    final mockLocationRepository = MockLocationRepository();
    final mockAirportRepository = MockAirportRepository();
    when(
      mockLocationRepository.getCurrentLocation,
    ).thenAnswer((_) async => const Left(NetworkFailure()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          airportRepositoryProvider.overrideWithValue(mockAirportRepository),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorldMapPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
