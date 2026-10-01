import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/location/location_repository.dart';
import 'package:gate_closes/core/location/location_repository_impl.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/domain/repositories/airport_repository.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_features.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/echo_map_repository.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/world_map_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/map_test_overrides.dart';

class MockLocationRepository extends Mock implements LocationRepository {}

class MockAirportRepository extends Mock implements AirportRepository {}

class MockEchoMapRepository extends Mock implements EchoMapRepository {}

void main() {
  late ProviderContainer container;
  late MockLocationRepository location;
  late MockAirportRepository airports;
  late MockEchoMapRepository echoMap;
  late MemoryMapDiskCache cache;

  const tCoordinates = LocationCoordinates(latitude: 1.35, longitude: 103.99);
  const tAirports = [
    AirportEntity(
      id: 'SIN',
      name: 'Singapore Changi Airport',
      iata: 'SIN',
      distanceKm: 2.1,
    ),
  ];
  const tPin = TerminalEchoMapNodeEntity(
    id: 'e1',
    senderId: '',
    nodeKind: EchoNodeKind.parallelSoul,
    latitude: 1.36,
    longitude: 103.98,
  );

  setUpAll(
    () => registerFallbackValue(
      const LocationCoordinates(latitude: 0, longitude: 0),
    ),
  );

  setUp(() {
    location = MockLocationRepository();
    airports = MockAirportRepository();
    echoMap = MockEchoMapRepository();
    cache = MemoryMapDiskCache();

    when(airports.getAirportGeoJson)
        .thenAnswer((_) async => const Right(<String, dynamic>{}));
    when(echoMap.getNodes)
        .thenAnswer((_) async => const Right(<TerminalEchoMapNodeEntity>[]));
  });

  tearDown(() => container.dispose());

  Future<WorldMapState> run({Map<String, Object> prefs = const {}}) async {
    container = ProviderContainer(
      overrides: [
        ...await mapTestOverrides(cache: cache, prefs: prefs),
        locationRepositoryProvider.overrideWithValue(location),
        airportRepositoryProvider.overrideWithValue(airports),
        echoMapRepositoryProvider.overrideWithValue(echoMap),
      ],
    )..read(worldMapControllerProvider);
    await pumpEventQueue();
    return container.read(worldMapControllerProvider);
  }

  group('WorldMapController', () {
    test('build() fetches nearby airports and the user location', () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Right(tCoordinates));
      when(() => airports.findNearby(tCoordinates))
          .thenAnswer((_) async => const Right(tAirports));

      final state = await run();

      expect(state.isLoading, false);
      expect(state.airports, tAirports);
      expect(state.userLocation, tCoordinates);
      expect(state.error, isNull);
    });

    test('a failed location fetch surfaces the error', () async {
      const tFailure = PermissionFailure('Location permission denied.');
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(tFailure));

      final state = await run();

      expect(state.isLoading, false);
      expect(state.airports, isEmpty);
      expect(state.error, tFailure.message);
    });

    test('a failed airport fetch surfaces the error', () async {
      const tFailure = ServerFailure('Boom');
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Right(tCoordinates));
      when(() => airports.findNearby(tCoordinates))
          .thenAnswer((_) async => const Left(tFailure));

      final state = await run();

      expect(state.airports, isEmpty);
      expect(state.error, tFailure.message);
    });

    test('offline: shows the pins cached by the last successful load',
        () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      cache.entries['pins'] = EchoMapFeatures.collection([tPin]);

      final state = await run();

      expect(state.echoNodes.map((n) => n.id), ['e1']);
      expect(state.echoNodes.single.nodeKind, EchoNodeKind.parallelSoul);
    });

    test('first load never requests pins without a map area', () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));

      await run();

      verifyNever(echoMap.getNodes);
    });

    test('a viewport fetch shows and caches the pins', () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      when(
        () => echoMap.getNodes(
          west: any(named: 'west'),
          south: any(named: 'south'),
          east: any(named: 'east'),
          north: any(named: 'north'),
        ),
      ).thenAnswer((_) async => const Right([tPin]));
      await run();

      await container
          .read(worldMapControllerProvider.notifier)
          .fetchEchoNodesForBounds(west: 103, south: 1, east: 104, north: 2);

      expect(container.read(worldMapControllerProvider).echoNodes, [tPin]);
      final cached = cache.entries['pins']!['features'] as List;
      expect(cached, hasLength(1));
    });

    test('a slow answer for an old viewport does not replace a newer one',
        () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      final oldViewport =
          Completer<Either<Failure, List<TerminalEchoMapNodeEntity>>>();
      const newPin = TerminalEchoMapNodeEntity(
        id: 'e2',
        senderId: '',
        nodeKind: EchoNodeKind.terminalEcho,
        latitude: 35.5,
        longitude: 139.7,
      );
      when(
        () => echoMap.getNodes(
          west: any(named: 'west'),
          south: any(named: 'south'),
          east: any(named: 'east'),
          north: any(named: 'north'),
        ),
      ).thenAnswer(
        (call) => call.namedArguments[#west] == 103.0
            ? oldViewport.future
            : Future.value(const Right([newPin])),
      );
      await run();
      final controller = container.read(worldMapControllerProvider.notifier);

      final old = controller.fetchEchoNodesForBounds(
        west: 103,
        south: 1,
        east: 104,
        north: 2,
      );
      await controller.fetchEchoNodesForBounds(
        west: 139,
        south: 35,
        east: 140,
        north: 36,
      );
      oldViewport.complete(
        const Right<Failure, List<TerminalEchoMapNodeEntity>>([tPin]),
      );
      await old;

      final state = container.read(worldMapControllerProvider);
      expect(state.echoNodes, [newPin]);
      expect(state.isFetchingPins, isFalse);
    });

    test('a recent remembered location centers the map before GPS', () async {
      // GPS never answers during this test.
      when(location.getCurrentLocation).thenAnswer(
        (_) => Future.delayed(
          const Duration(days: 1),
          () => const Left(NetworkFailure()),
        ),
      );
      final remembered = jsonEncode({
        'lat': 14.5,
        'lng': 121.0,
        'at': DateTime.now().millisecondsSinceEpoch,
      });

      final state = await run(prefs: {'map_last_location': remembered});

      expect(
        state.userLocation,
        const LocationCoordinates(latitude: 14.5, longitude: 121),
      );
    });

    test('the remembered location is stored at ~110 m precision', () async {
      when(location.getCurrentLocation).thenAnswer(
        (_) async => const Right(
          LocationCoordinates(latitude: 14.508123, longitude: 121.019876),
        ),
      );
      when(() => airports.findNearby(any()))
          .thenAnswer((_) async => const Right(<AirportEntity>[]));

      await run();

      final stored = jsonDecode(
        container
            .read(sharedPreferencesProvider)
            .getString('map_last_location')!,
      ) as Map<String, dynamic>;
      expect(stored['lat'], 14.508);
      expect(stored['lng'], 121.02);
    });

    test('an old remembered location is ignored', () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      final stale = jsonEncode({
        'lat': 14.5,
        'lng': 121.0,
        'at': DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      });

      final state = await run(prefs: {'map_last_location': stale});

      expect(state.userLocation, isNull);
    });
  });
}
