import 'dart:math' as math;

import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_beacons.dart';

/// The zoomed-out heat as clouds, not circles: one heat point per airport
/// always draws a perfect disc with ring-shaped color bands, so each
/// airport is fed as a small cluster of "puffs" scattered around it,
/// wider than tall, which melt into a lumpy cloud.
///
/// The scatter is in screen points (converted for the current zoom, like
/// the airport's other markers), tight around the airport when zoomed out
/// so neighbouring airports keep their own clouds, and growing as the
/// camera comes in ([zoomScale]); the map rebuilds the puffs when the zoom
/// changes. Each airport's pattern comes from its code, so it never
/// reshuffles between rebuilds.
abstract final class AirportClouds {
  /// Puffs per airport, besides the one on the airport itself.
  static const int puffs = 9;

  /// How far puffs scatter, in points, times the airport's `cloudScale`.
  static const double spreadPoints = 17;

  /// Clouds are wider than tall.
  static const double stretchX = 1.6;
  static const double stretchY = 0.75;

  static const double _metersPerDegreeLat = 111320;

  /// How much of [spreadPoints] the scatter uses at [zoom]: about a third
  /// at globe zoom, all of it by the airport zoom.
  static double zoomScale(double zoom) =>
      (0.35 + (zoom - 2) * 0.09).clamp(0.35, 1.0);

  /// The puffs of every airport in [counts] at [zoom]. Each carries the
  /// airport's `airportIata`, `count`, `cloudScale` and `freshnessScore`,
  /// and a `heatWeight` share of its airport's.
  static Map<String, dynamic> collection(
    List<AirportEchoCount> counts, {
    required double zoom,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final c in counts) ..._puffs(c, zoom, at),
      ],
    };
  }

  static Iterable<Map<String, dynamic>> _puffs(
    AirportEchoCount c,
    double zoom,
    DateTime now,
  ) sync* {
    final random = math.Random(_seed(c.airportIata));
    final perPoint = EchoBeacons.metersPerPoint(zoom, c.latitude);
    final spread = spreadPoints * zoomScale(zoom) * c.cloudScale * perPoint;
    final cosLat = math.cos(c.latitude * math.pi / 180);
    final fresh = c.latestAt != null &&
        now.difference(c.latestAt!) <= AirportEchoCount.newMaxAge;
    for (var i = 0; i <= puffs; i++) {
      // The first puff sits on the airport, at full weight.
      final angle = random.nextDouble() * 2 * math.pi;
      final reach = i == 0 ? 0.0 : spread * (0.3 + 0.7 * random.nextDouble());
      final weight = i == 0 ? 1.0 : 0.45 + 0.55 * random.nextDouble();
      final east = reach * stretchX * math.cos(angle);
      final north = reach * stretchY * math.sin(angle);
      yield {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [
            c.longitude + east / (_metersPerDegreeLat * cosLat),
            c.latitude + north / _metersPerDegreeLat,
          ],
        },
        'properties': {
          'airportIata': c.airportIata,
          'count': c.count,
          'cloudScale': c.cloudScale,
          'freshnessScore': fresh ? 2 : 1,
          // Overlapping puffs add up; a share keeps the cloud as hot as
          // the single point was.
          'heatWeight': c.heatWeight * weight * 0.3,
        },
      };
    }
  }

  /// A stable seed from the airport code (String.hashCode may change
  /// between runs).
  static int _seed(String iata) =>
      iata.codeUnits.fold(17, (h, u) => (h * 31 + u) & 0x7fffffff);
}
