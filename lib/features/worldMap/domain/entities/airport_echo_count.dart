import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Echoes at one airport, for the zoomed-out map: one heatmap point per
/// airport instead of every pin (`GET /terminal-echo/map/counts`).
class AirportEchoCount extends Equatable {
  const AirportEchoCount({
    required this.airportIata,
    required this.count,
    required this.latitude,
    required this.longitude,
    this.airportName,
    this.latestAt,
  });

  /// Null when the feature has no airport code or no usable point.
  static AirportEchoCount? fromGeoJsonFeature(Map<String, dynamic> feature) {
    final properties =
        (feature['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
    final coordinates = (feature['geometry'] as Map?)?['coordinates'];
    final iata = (properties['airportIata'] ?? feature['id'])?.toString();
    if (iata == null || iata.isEmpty) return null;
    if (coordinates is! List || coordinates.length < 2) return null;
    final lng = coordinates[0];
    final lat = coordinates[1];
    if (lng is! num || lat is! num) return null;
    final latestAt = properties['latestAt'];
    return AirportEchoCount(
      airportIata: iata,
      airportName: properties['airportName']?.toString(),
      count: (properties['count'] as num?)?.toInt() ?? 0,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      latestAt: latestAt == null ? null : DateTime.tryParse('$latestAt'),
    );
  }

  final String airportIata;
  final String? airportName;
  final int count;
  final double latitude;
  final double longitude;
  final DateTime? latestAt;

  /// An airport whose newest echo is younger than this glows as "new" on
  /// the heatmap, like a fresh pin.
  static const newMaxAge = Duration(minutes: 20);

  /// Heatmap weight: one point stands for [count] echoes, so it glows
  /// brighter with more of them, on a log scale (1 → ~1, 12 → ~1.4) and
  /// capped so one busy airport doesn't wash out the map.
  double get heatWeight =>
      math.min(2, 0.8 + 0.25 * math.log(1 + math.max(0, count)));

  /// Cloud size multiplier, also log-scaled (1 → ~1.2, 12 → ~1.8), capped.
  double get cloudScale =>
      math.min(2.4, 1 + 0.3 * math.log(1 + math.max(0, count)));

  /// The GeoJSON the zoomed-out airport clouds render: [heatWeight] and
  /// [cloudScale] per airport, plus the pin heatmap's scores.
  static Map<String, dynamic> collection(
    List<AirportEchoCount> counts, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final c in counts)
          {
            'type': 'Feature',
            'id': c.airportIata,
            'geometry': {
              'type': 'Point',
              'coordinates': [c.longitude, c.latitude],
            },
            'properties': {
              'airportIata': c.airportIata,
              if (c.airportName != null) 'airportName': c.airportName,
              'count': c.count,
              'heatWeight': c.heatWeight,
              'cloudScale': c.cloudScale,
              if (c.latestAt != null) 'latestAt': c.latestAt!.toIso8601String(),
              'activityScore': c.count >= 10
                  ? 2
                  : c.count >= 3
                      ? 1
                      : 0,
              'freshnessScore':
                  c.latestAt != null && at.difference(c.latestAt!) <= newMaxAge
                      ? 2
                      : 1,
            },
          },
      ],
    };
  }

  @override
  List<Object?> get props =>
      [airportIata, airportName, count, latitude, longitude, latestAt];
}
