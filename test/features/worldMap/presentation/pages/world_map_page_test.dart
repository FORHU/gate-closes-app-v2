import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/location/location_repository.dart';
import 'package:gate_closes/core/location/location_repository_impl.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/domain/repositories/airport_repository.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/echo_map_repository.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/world_map_controller.dart';
import 'package:gate_closes/features/worldMap/presentation/pages/world_map_page.dart';
import 'package:gate_closes/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/map_test_overrides.dart';

class MockLocationRepository extends Mock implements LocationRepository {}

class MockAirportRepository extends Mock implements AirportRepository {}

class MockEchoMapRepository extends Mock implements EchoMapRepository {}

const _tCoordinates = LocationCoordinates(latitude: 1.35, longitude: 103.99);

void main() {
  late MockLocationRepository location;
  late MockAirportRepository airports;
  late MockEchoMapRepository echoMap;

  setUp(() {
    location = MockLocationRepository();
    airports = MockAirportRepository();
    echoMap = MockEchoMapRepository();
    when(airports.getAirportGeoJson)
        .thenAnswer((_) async => const Right(<String, dynamic>{}));
    when(echoMap.getNodes).thenAnswer(
      (_) async => const Right(<TerminalEchoMapNodeEntity>[]),
    );
    when(location.watchPosition).thenAnswer((_) => const Stream.empty());
    when(() => airports.findNearby(_tCoordinates)).thenAnswer(
      (_) async => const Right([
        AirportEntity(id: 'SIN', name: 'Singapore Changi', iata: 'SIN'),
      ]),
    );
  });

  Future<void> pumpMap(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    final extra = await mapTestOverrides(prefs: prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...extra,
          locationRepositoryProvider.overrideWithValue(location),
          airportRepositoryProvider.overrideWithValue(airports),
          echoMapRepositoryProvider.overrideWithValue(echoMap),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: WorldMapPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the airport search pill over the map', (tester) async {
    when(location.getCurrentLocation)
        .thenAnswer((_) async => const Right(_tCoordinates));

    await pumpMap(tester);

    expect(find.text('SEARCH AIRPORT...'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers recenter once the user location is known', (
    tester,
  ) async {
    when(location.getCurrentLocation)
        .thenAnswer((_) async => const Right(_tCoordinates));

    await pumpMap(tester);

    expect(
      find.byTooltip('Recenter map to your location'),
      findsOneWidget,
    );
  });

  testWidgets('no recenter button without a location', (tester) async {
    when(location.getCurrentLocation).thenAnswer(
      (_) async => const Left(PermissionFailure('Location denied')),
    );

    await pumpMap(tester);

    expect(find.byTooltip('Recenter map to your location'), findsNothing);
    expect(find.text('SEARCH AIRPORT...'), findsOneWidget);
  });

  testWidgets('offline: explains that saved data is shown', (tester) async {
    when(location.getCurrentLocation)
        .thenAnswer((_) async => const Right(_tCoordinates));
    final extra = await mapTestOverrides(offline: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...extra,
          locationRepositoryProvider.overrideWithValue(location),
          airportRepositoryProvider.overrideWithValue(airports),
          echoMapRepositoryProvider.overrideWithValue(echoMap),
        ],
        child: const MaterialApp(home: Scaffold(body: WorldMapPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NO INTERNET — SHOWING SAVED DATA'), findsOneWidget);
  });

  group('map render guard', () {
    setUp(() {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Right(_tCoordinates));
    });

    testWidgets('marks the attempt before the map starts', (tester) async {
      await pumpMap(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('map_render_pending'), 'pending');
      expect(find.text('SEARCH AIRPORT...'), findsOneWidget);
    });

    testWidgets('last launch died loading the map: shows the notice', (
      tester,
    ) async {
      await pumpMap(tester, prefs: {'map_render_pending': 'pending'});

      expect(find.text("Map isn't available on this phone"), findsOneWidget);
      expect(find.text('SEARCH AIRPORT...'), findsNothing);
    });

    testWidgets('try again brings the map back', (tester) async {
      await pumpMap(tester, prefs: {'map_render_pending': 'pending'});

      await tester.tap(find.text('Try the map again'));
      await tester.pumpAndSettle();

      expect(find.text("Map isn't available on this phone"), findsNothing);
      expect(find.text('SEARCH AIRPORT...'), findsOneWidget);
    });

    testWidgets('map never finishes loading: shows the notice', (
      tester,
    ) async {
      await pumpMap(tester);

      await tester.pump(const Duration(seconds: 26));
      await tester.pumpAndSettle();

      expect(find.text("Map isn't available on this phone"), findsOneWidget);
    });
  });
}
