import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/location/domain/entities/location_coordinates.dart';
import 'package:fpdart/fpdart.dart';

abstract class LocationRepository {
  /// Request device location permissions. Returns true if granted.
  Future<Either<Failure, bool>> requestPermission();

  /// Gets current GPS coordinates.
  Future<Either<Failure, LocationCoordinates>> getCurrentLocation();

  /// Checks if location services are enabled on the device.
  Future<bool> isLocationServiceEnabled();
}
