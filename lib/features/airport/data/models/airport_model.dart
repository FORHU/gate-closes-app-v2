import 'package:flutter_template/features/airport/domain/entities/airport_entity.dart';

class AirportModel extends AirportEntity {
  const AirportModel({
    required super.id,
    required super.name,
    required super.iata,
    super.icao,
    super.countryCode,
    super.distanceKm,
    super.latitude,
    super.longitude,
    super.insideBoundary = false,
    super.detectionState = AirportDetectionState.unknown,
  });

  /// Parses both the `checkInsideAirport` shape (single object, `_id`,
  /// `insideRadius`, `distanceKm`) and the `/airport/nearby` shape (each
  /// list item — no `_id` on freshly-fetched-and-mapped results, no
  /// `distanceKm`, but a GeoJSON `location.coordinates`). See
  /// `gate-closes-api/src/services/airport.service.ts` (`mapRawAirport`,
  /// `findNearbyAndStore`).
  factory AirportModel.fromJson(Map<String, dynamic> json) {
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map)
            ? (json['data'] as Map).cast<String, dynamic>()
            : json;

    final iata = (payload['iata'] ?? '').toString();
    // /airport/nearby results have no `_id` (they're mapped, not yet
    // re-fetched from the DB) — fall back to `iata` so list keys stay
    // unique instead of colliding on ''.
    final id = (payload['_id'] ?? payload['id'] ?? iata).toString();
    final name = (payload['airport'] ?? payload['name'] ?? '').toString();
    final icao = payload['icao'] as String?;
    final countryCode =
        (payload['countryCode'] ?? payload['country_code']) as String?;

    final location = payload['location'];
    final coordinates =
        location is Map ? location['coordinates'] as List? : null;
    // GeoJSON order is [lng, lat].
    final longitude = coordinates != null && coordinates.length > 1
        ? (coordinates[0] as num).toDouble()
        : null;
    final latitude = coordinates != null && coordinates.length > 1
        ? (coordinates[1] as num).toDouble()
        : null;

    final insideRadius = payload['insideRadius'] == true;
    final insideBoundary = payload['insideBoundary'] == true || insideRadius;

    final dist = payload['distanceKm'];
    final distanceKm = dist is num ? dist.toDouble() : null;

    var state = AirportDetectionState.outsideAirport;
    if (insideBoundary) {
      state = AirportDetectionState.insideAirport;
    } else if (distanceKm != null && distanceKm <= 10.0) {
      state = AirportDetectionState.approaching;
    }

    return AirportModel(
      id: id,
      name: name,
      iata: iata,
      icao: icao,
      countryCode: countryCode,
      distanceKm: distanceKm,
      latitude: latitude,
      longitude: longitude,
      insideBoundary: insideBoundary,
      detectionState: state,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iata': iata,
        'icao': icao,
        'countryCode': countryCode,
        'distanceKm': distanceKm,
        'insideBoundary': insideBoundary,
        'detectionState': detectionState.name,
      };
}
