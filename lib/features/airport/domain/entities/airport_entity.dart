import 'package:equatable/equatable.dart';

/// Airport spatial status as determined by the backend evaluation.
enum AirportDetectionState {
  insideAirport,
  approaching,
  outsideAirport,
  unknown,
}

/// Domain entity representing a resolved airport geofence match.
class AirportEntity extends Equatable {
  const AirportEntity({
    required this.id,
    required this.name,
    required this.iata,
    this.icao,
    this.countryCode,
    this.distanceKm,
    this.latitude,
    this.longitude,
    this.insideBoundary = false,
    this.detectionState = AirportDetectionState.unknown,
  });

  final String id;
  final String name;
  final String iata;
  final String? icao;
  final String? countryCode;
  final double? distanceKm;

  /// From the backend's GeoJSON `location.coordinates` — null for responses
  /// that don't include it (e.g. `checkInsideAirport`, which only returns
  /// the resolved airport's identity, not its coordinates).
  final double? latitude;
  final double? longitude;
  final bool insideBoundary;
  final AirportDetectionState detectionState;

  AirportEntity copyWith({
    String? id,
    String? name,
    String? iata,
    String? icao,
    String? countryCode,
    double? distanceKm,
    double? latitude,
    double? longitude,
    bool? insideBoundary,
    AirportDetectionState? detectionState,
  }) {
    return AirportEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      iata: iata ?? this.iata,
      icao: icao ?? this.icao,
      countryCode: countryCode ?? this.countryCode,
      distanceKm: distanceKm ?? this.distanceKm,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      insideBoundary: insideBoundary ?? this.insideBoundary,
      detectionState: detectionState ?? this.detectionState,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        iata,
        icao,
        countryCode,
        distanceKm,
        latitude,
        longitude,
        insideBoundary,
        detectionState,
      ];
}
