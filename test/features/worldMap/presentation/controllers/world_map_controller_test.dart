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
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_pin_plan.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_features.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_offer.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/echo_map_repository.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/offer_map_repository.dart';
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
  late FakeMapEchoSocket socket;

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
  const tCounts = [
    AirportEchoCount(
      airportIata: 'SIN',
      count: 1,
      latitude: 1.3644,
      longitude: 103.9915,
    ),
    AirportEchoCount(
      airportIata: 'MNL',
      count: 12,
      latitude: 14.5112,
      longitude: 121.0192,
    ),
  ];

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
    socket = FakeMapEchoSocket();

    when(airports.getAirportGeoJson)
        .thenAnswer((_) async => const Right(<String, dynamic>{}));
    when(() => echoMap.getAirportNodes(any()))
        .thenAnswer((_) async => const Right(<TerminalEchoMapNodeEntity>[]));
    when(echoMap.getAirportCounts)
        .thenAnswer((_) async => const Right(tCounts));
  });

  tearDown(() => container.dispose());

  Future<WorldMapState> run({
    Map<String, Object> prefs = const {},
    FakeOfferMapRepository? offers,
  }) async {
    container = ProviderContainer(
      overrides: [
        ...await mapTestOverrides(
          cache: cache,
          prefs: prefs,
          socket: socket,
          offers: offers,
        ),
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

    test('first load never requests pins or counts without a map area',
        () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));

      await run();

      verifyNever(() => echoMap.getAirportNodes(any()));
      verifyNever(echoMap.getAirportCounts);
    });

    /// A view around Singapore at [zoom].
    Future<void> viewSingapore(double zoom) =>
        container.read(worldMapControllerProvider.notifier).refreshForView(
              west: 103.5,
              south: 1,
              east: 104.5,
              north: 2,
              zoom: zoom,
              centerLng: 104,
              centerLat: 1.5,
            );

    group('offers', () {
      const card = MapOffer(
        id: 'card1',
        airportIata: 'SIN',
        kind: 'voucher',
        title: 'Coffee 20% off',
      );
      const pin = MapOffer(
        id: 'pin1',
        airportIata: 'SIN',
        kind: 'ad',
        title: 'Lounge',
        longitude: 103.99,
        latitude: 1.36,
      );
      FakeOfferMapRepository sinOffers() => FakeOfferMapRepository(
            offers: {
              'SIN': const AirportOffers(card: card, pins: [pin]),
            },
          );

      test('zoomed in: the airports in view get their offer pins', () async {
        when(location.getCurrentLocation)
            .thenAnswer((_) async => const Left(NetworkFailure()));
        final offers = sinOffers();
        await run(offers: offers);

        await viewSingapore(12);
        await pumpEventQueue();

        final state = container.read(worldMapControllerProvider);
        expect(state.offerPins, [pin]);
        expect(offers.requested, ['SIN']);
      });

      test('fetched once while fresh, and cleared when zoomed out', () async {
        when(location.getCurrentLocation)
            .thenAnswer((_) async => const Left(NetworkFailure()));
        final offers = sinOffers();
        await run(offers: offers);

        await viewSingapore(12);
        await pumpEventQueue();
        await viewSingapore(13);
        await pumpEventQueue();
        expect(offers.requested, ['SIN']);

        await viewSingapore(4);
        final state = container.read(worldMapControllerProvider);
        expect(state.offerPins, isEmpty);
      });

      test('failing offers leave the echo pins as they are', () async {
        when(location.getCurrentLocation)
            .thenAnswer((_) async => const Left(NetworkFailure()));
        when(() => echoMap.getAirportNodes('SIN'))
            .thenAnswer((_) async => const Right([tPin]));
        await run(offers: FakeOfferMapRepository(fail: true));

        await viewSingapore(12);
        await pumpEventQueue();

        final state = container.read(worldMapControllerProvider);
        expect(state.echoNodes, [tPin]);
        expect(state.offerPins, isEmpty);
        expect(state.error, isNull);
      });

      test('tracking and claiming go to the repository', () async {
        final offers = sinOffers();
        when(location.getCurrentLocation)
            .thenAnswer((_) async => const Left(NetworkFailure()));
        await run(offers: offers);
        final controller = container.read(worldMapControllerProvider.notifier)
          ..trackOffer(card, OfferEvent.view);

        final reward = await controller.claimOffer(card);
        await pumpEventQueue();

        expect(offers.events, [('card1', OfferEvent.view)]);
        expect(offers.claims, ['card1']);
        expect(reward.getOrElse((_) => fail('expected Right')).code, 'GATE20');
      });
    });

    test('zoomed out: shows per-airport counts, no pins', () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      await run();

      await viewSingapore(4);

      final state = container.read(worldMapControllerProvider);
      expect(state.pinMode, MapPinMode.counts);
      expect(state.airportCounts, tCounts);
      expect(state.isFetchingPins, isFalse);
      verifyNever(() => echoMap.getAirportNodes(any()));
      expect(socket.watched, isEmpty);
    });

    test('zoomed in: loads only the airports in view, caches and watches them',
        () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      when(() => echoMap.getAirportNodes('SIN'))
          .thenAnswer((_) async => const Right([tPin]));
      await run();

      await viewSingapore(12);
      await viewSingapore(13);

      final state = container.read(worldMapControllerProvider);
      expect(state.pinMode, MapPinMode.pins);
      expect(state.echoNodes, [tPin]);
      // Fetched once (cached after), and never MNL: it's not in view.
      verify(() => echoMap.getAirportNodes('SIN')).called(1);
      verifyNever(() => echoMap.getAirportNodes('MNL'));
      // Counts are fresh for a minute: one request for both views.
      verify(echoMap.getAirportCounts).called(1);
      expect(socket.watched, {'SIN'});
      final cached = cache.entries['pins']!['features'] as List;
      expect(cached, hasLength(1));
    });

    test('views refreshed at once share one request each', () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      when(() => echoMap.getAirportNodes('SIN'))
          .thenAnswer((_) async => const Right([tPin]));
      await run();

      await Future.wait([viewSingapore(12), viewSingapore(12.5)]);

      verify(echoMap.getAirportCounts).called(1);
      verify(() => echoMap.getAirportNodes('SIN')).called(1);
      expect(container.read(worldMapControllerProvider).echoNodes, [tPin]);
    });

    test('a new echo at a watched airport reloads its pins', () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      const newPin = TerminalEchoMapNodeEntity(
        id: 'e2',
        senderId: '',
        nodeKind: EchoNodeKind.terminalEcho,
        latitude: 1.36,
        longitude: 103.98,
      );
      var answer = const [tPin];
      when(() => echoMap.getAirportNodes('SIN'))
          .thenAnswer((_) async => Right(answer));
      await run();
      await viewSingapore(12);

      answer = const [newPin, tPin];
      socket.emit('SIN');
      await pumpEventQueue();

      expect(
        container.read(worldMapControllerProvider).echoNodes,
        [newPin, tPin],
      );
    });

    test('a new echo elsewhere reloads nothing on screen', () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      when(() => echoMap.getAirportNodes('SIN'))
          .thenAnswer((_) async => const Right([tPin]));
      await run();
      await viewSingapore(12);

      socket.emit('MNL');
      await pumpEventQueue();

      verify(() => echoMap.getAirportNodes('SIN')).called(1);
    });

    test('a slow answer for an old view does not replace a newer one',
        () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      final slowSin =
          Completer<Either<Failure, List<TerminalEchoMapNodeEntity>>>();
      when(() => echoMap.getAirportNodes('SIN'))
          .thenAnswer((_) => slowSin.future);
      await run();
      final controller = container.read(worldMapControllerProvider.notifier);

      final old = viewSingapore(12);
      await pumpEventQueue(); // now waiting on the SIN pins
      await controller.refreshForView(
        west: -180,
        south: -85,
        east: 180,
        north: 85,
        zoom: 3,
        centerLng: 0,
        centerLat: 0,
      );
      slowSin.complete(
        const Right<Failure, List<TerminalEchoMapNodeEntity>>([tPin]),
      );
      await old;

      final state = container.read(worldMapControllerProvider);
      expect(state.pinMode, MapPinMode.counts);
      expect(state.echoNodes, isEmpty);
      expect(state.isFetchingPins, isFalse);
    });

    test('offline: counts and pins come from the disk cache', () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      when(echoMap.getAirportCounts)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      when(() => echoMap.getAirportNodes(any()))
          .thenAnswer((_) async => const Left(NetworkFailure()));
      cache.entries['counts'] = AirportEchoCount.collection(tCounts);
      cache.entries['pins'] = EchoMapFeatures.collection([tPin]);
      await run();

      await viewSingapore(4);
      expect(
        container.read(worldMapControllerProvider).airportCounts.map(
              (c) => c.airportIata,
            ),
        ['SIN', 'MNL'],
      );

      await viewSingapore(12);
      expect(container.read(worldMapControllerProvider).echoNodes, [tPin]);
    });

    test('disposing the map closes the socket', () async {
      when(location.getCurrentLocation)
          .thenAnswer((_) async => const Left(NetworkFailure()));
      await run();
      await viewSingapore(12);

      container.dispose();

      expect(socket.disposed, isTrue);
      // tearDown disposes again: harmless.
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
