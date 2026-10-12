import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/airports/airport_reference.dart';
import 'package:gate_closes/core/airports/local_airport_registry.dart';
import 'package:gate_closes/core/config/app_config.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/location/location_repository.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';

/// Granted by the API (via `GET /auth/me`) to staff roles only.
const simulateAirportPermission = 'airports:simulate';
const _storageKey = 'dev_simulated_airport';

/// `airportType` of a test airport made with "Create Airport Here" (it lives
/// on the API, only for its creator; it's not in the bundled registry).
const testAirportType = 'test';

/// Whether this build and the signed-in user may simulate an airport: dev
/// builds only, and only with [simulateAirportPermission].
final canSimulateAirportProvider = Provider<bool>((ref) {
  if (!AppConfig.instance.isDev) return false;
  return ref.watch(
    authControllerProvider.select(
      (s) => s.user?.permissions.contains(simulateAirportPermission) ?? false,
    ),
  );
});

/// The airport the app pretends to be at, or null for real GPS. Always null
/// when [canSimulateAirportProvider] is false, so a choice saved on a shared
/// device does nothing for other accounts or in prod builds.
class SimulatedAirportController extends Notifier<AirportReference?> {
  @override
  AirportReference? build() {
    if (!ref.watch(canSimulateAirportProvider)) return null;
    final saved = ref.read(storageServiceProvider).getString(_storageKey);
    if (saved == null) return null;
    try {
      return AirportReference.fromJson(
        (jsonDecode(saved) as Map).cast<String, dynamic>(),
      );
    } on Object catch (_) {
      // Saved by an older build as a bare IATA code.
      return LocalAirportRegistry.instance.resolveAirport(saved);
    }
  }

  /// Returns false when not allowed or [iata] isn't a known airport.
  Future<bool> simulate(String iata) async {
    if (!ref.read(canSimulateAirportProvider)) return false;
    final airport = LocalAirportRegistry.instance.resolveAirport(iata);
    if (airport == null) return false;
    return simulateAt(airport);
  }

  /// Simulates being at [airport], e.g. a test airport just created on the
  /// API. Returns false when not allowed.
  Future<bool> simulateAt(AirportReference airport) async {
    if (!ref.read(canSimulateAirportProvider)) return false;
    await ref
        .read(storageServiceProvider)
        .setString(_storageKey, jsonEncode(airport.toJson()));
    state = airport;
    return true;
  }

  Future<void> clear() async {
    await ref.read(storageServiceProvider).remove(_storageKey);
    state = null;
  }
}

final simulatedAirportProvider =
    NotifierProvider<SimulatedAirportController, AirportReference?>(
  SimulatedAirportController.new,
);

/// Reports the simulated airport's reference point as the device position.
/// Everything downstream (airport check, echo posting) still goes through
/// the real API, which applies its normal radius checks.
class SimulatedLocationRepository implements LocationRepository {
  SimulatedLocationRepository(AirportReference airport)
      : _at = LocationCoordinates(
          latitude: airport.latitude,
          longitude: airport.longitude,
        );

  final LocationCoordinates _at;

  @override
  Future<Either<Failure, bool>> requestPermission() async => const Right(true);

  @override
  Future<Either<Failure, LocationCoordinates>> getCurrentLocation() async =>
      Right(_at);

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<LocationCoordinates> watchPosition({int distanceFilter = 25}) =>
      Stream.value(_at);
}
