import 'dart:math' as math;
import 'package:equatable/equatable.dart';

/// Pure domain coordinates representing geographic latitude and longitude.
class LocationCoordinates extends Equatable {
  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  /// Quantizes coordinates to a given decimal precision to preserve
  /// traveler privacy (e.g. precision 3 corresponds to ~110m at the equator).
  /// Matches the backend quantization contract:
  /// `Math.round(coordinate * factor) / factor` where `factor = 10^precision`.
  LocationCoordinates quantize({int precision = 3}) {
    final factor = math.pow(10, precision);
    final quantizedLat = (latitude * factor).round() / factor;
    final quantizedLng = (longitude * factor).round() / factor;
    return LocationCoordinates(
      latitude: quantizedLat,
      longitude: quantizedLng,
    );
  }

  /// Great-circle distance to [other], in meters (haversine).
  double distanceTo(LocationCoordinates other) {
    const earthRadius = 6371e3;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLng = rad(other.longitude - longitude);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  List<Object?> get props => [latitude, longitude];
}
