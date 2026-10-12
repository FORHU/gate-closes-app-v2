import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/airports/airport_reference.dart';
import 'package:gate_closes/core/airports/local_airport_registry.dart';
import 'package:gate_closes/core/config/app_config.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/location/location_repository_impl.dart';
import 'package:gate_closes/core/location/simulated_airport.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/domain/entities/user_entity.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthController {
  _Auth(this.permissions);
  final List<String> permissions;

  @override
  AuthState build() => AuthState(
        user: UserEntity(
          id: 'u1',
          email: 'u1@example.com',
          name: 'u1',
          permissions: permissions,
        ),
      );
}

Future<ProviderContainer> _container(List<String> permissions) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authControllerProvider.overrideWith(() => _Auth(permissions)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(() {
    LocalAirportRegistry.instance.loadFromJsonString(
      '[{"iata":"MNL", "name":"Ninoy Aquino International Airport", '
      '"latitude":14.5086, "longitude":121.0198}]',
    );
  });

  setUp(() => AppConfig.instance = const AppConfig.dev());

  test('staff in a dev build: location comes from the simulated airport',
      () async {
    final c = await _container([simulateAirportPermission]);
    final sim = c.read(simulatedAirportProvider.notifier);

    expect(await sim.simulate('XXX'), isFalse);
    expect(await sim.simulate('mnl'), isTrue);

    final location =
        await c.read(locationRepositoryProvider).getCurrentLocation();
    expect(
      location.getOrElse((_) => throw StateError('no location')),
      const LocationCoordinates(latitude: 14.5086, longitude: 121.0198),
    );

    await sim.clear();
    expect(c.read(locationRepositoryProvider), isA<LocationRepositoryImpl>());
  });

  test('a created test airport is simulated and survives a rebuild', () async {
    final c = await _container([simulateAirportPermission]);
    const testAirport = AirportReference(
      iata: 'T00001',
      name: 'Test airport',
      city: '',
      countryCode: '',
      timezone: 'UTC',
      latitude: 10.25,
      longitude: 123.75,
      airportType: testAirportType,
    );

    expect(
      await c.read(simulatedAirportProvider.notifier).simulateAt(testAirport),
      isTrue,
    );
    c.invalidate(simulatedAirportProvider);

    expect(c.read(simulatedAirportProvider), testAirport);
    final location =
        await c.read(locationRepositoryProvider).getCurrentLocation();
    expect(
      location.getOrElse((_) => throw StateError('no location')),
      const LocationCoordinates(latitude: 10.25, longitude: 123.75),
    );
  });

  test('without the permission: real GPS, even with a saved simulation',
      () async {
    final c = await _container([]);
    await c
        .read(storageServiceProvider)
        .setString('dev_simulated_airport', 'MNL');

    final sim = c.read(simulatedAirportProvider.notifier);
    expect(c.read(canSimulateAirportProvider), isFalse);
    expect(await sim.simulate('MNL'), isFalse);
    expect(c.read(locationRepositoryProvider), isA<LocationRepositoryImpl>());
  });

  test('prod build: never simulates, even for staff', () async {
    AppConfig.instance = const AppConfig.prod();
    final c = await _container([simulateAirportPermission]);
    final sim = c.read(simulatedAirportProvider.notifier);

    expect(await sim.simulate('MNL'), isFalse);
    expect(c.read(locationRepositoryProvider), isA<LocationRepositoryImpl>());
  });
}
