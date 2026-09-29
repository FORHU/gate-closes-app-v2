import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/domain/repositories/airport_repository.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/location/domain/entities/location_coordinates.dart';
import 'package:gate_closes/features/location/domain/repositories/location_repository.dart';
import 'package:gate_closes/features/terminal_echo/domain/repositories/terminal_echo_repository.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/world_map_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockLocationRepository extends Mock implements LocationRepository {}

class MockAirportRepository extends Mock implements AirportRepository {}

class MockTerminalEchoRepository extends Mock
    implements TerminalEchoRepository {}

void main() {
  late ProviderContainer container;
  late MockLocationRepository mockLocationRepository;
  late MockAirportRepository mockAirportRepository;
  late MockTerminalEchoRepository mockTerminalEchoRepository;

  const tCoordinates = LocationCoordinates(latitude: 1.35, longitude: 103.99);
  const tAirports = [
    AirportEntity(
      id: 'SIN',
      name: 'Singapore Changi Airport',
      iata: 'SIN',
      distanceKm: 2.1,
    ),
  ];

  setUp(() {
    mockLocationRepository = MockLocationRepository();
    mockAirportRepository = MockAirportRepository();
    mockTerminalEchoRepository = MockTerminalEchoRepository();

    when(
      mockAirportRepository.getAirportGeoJson,
    ).thenAnswer((_) async => const Right(<String, dynamic>{}));
    when(
      mockTerminalEchoRepository.getMapGeoJson,
    ).thenAnswer(
      (_) async => const Right(<String, dynamic>{'features': <dynamic>[]}),
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('WorldMapController', () {
    test('build() fetches nearby airports in the background', () async {
      when(
        mockLocationRepository.getCurrentLocation,
      ).thenAnswer((_) async => const Right(tCoordinates));
      when(
        () => mockAirportRepository.findNearby(tCoordinates),
      ).thenAnswer((_) async => const Right(tAirports));

      container = ProviderContainer(
        overrides: [
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          airportRepositoryProvider.overrideWithValue(mockAirportRepository),
          terminalEchoRepositoryProvider.overrideWithValue(
            mockTerminalEchoRepository,
          ),
        ],
      )..read(worldMapControllerProvider);

      await Future<void>.delayed(Duration.zero);

      final state = container.read(worldMapControllerProvider);
      expect(state.isLoading, false);
      expect(state.airports, tAirports);
      expect(state.error, isNull);
    });

    test('a failed location fetch surfaces the error', () async {
      const tFailure = PermissionFailure('Location permission denied.');
      when(
        mockLocationRepository.getCurrentLocation,
      ).thenAnswer((_) async => const Left(tFailure));

      container = ProviderContainer(
        overrides: [
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          airportRepositoryProvider.overrideWithValue(mockAirportRepository),
          terminalEchoRepositoryProvider.overrideWithValue(
            mockTerminalEchoRepository,
          ),
        ],
      )..read(worldMapControllerProvider);

      await Future<void>.delayed(Duration.zero);

      final state = container.read(worldMapControllerProvider);
      expect(state.isLoading, false);
      expect(state.airports, isEmpty);
      expect(state.error, tFailure.message);
    });

    test('a failed airport fetch surfaces the error and keeps airports empty',
        () async {
      const tFailure = ServerFailure('Boom');
      when(
        mockLocationRepository.getCurrentLocation,
      ).thenAnswer((_) async => const Right(tCoordinates));
      when(
        () => mockAirportRepository.findNearby(tCoordinates),
      ).thenAnswer((_) async => const Left(tFailure));

      container = ProviderContainer(
        overrides: [
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          airportRepositoryProvider.overrideWithValue(mockAirportRepository),
          terminalEchoRepositoryProvider.overrideWithValue(
            mockTerminalEchoRepository,
          ),
        ],
      )..read(worldMapControllerProvider);

      await Future<void>.delayed(Duration.zero);

      final state = container.read(worldMapControllerProvider);
      expect(state.isLoading, false);
      expect(state.airports, isEmpty);
      expect(state.error, tFailure.message);
    });
  });
}
