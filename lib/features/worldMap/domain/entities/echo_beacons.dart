import 'dart:math' as math;

import 'package:gate_closes/features/worldMap/domain/entities/airport_radar.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_features.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';

/// One echo where the map draws it: its own spot, or nudged off a spot it
/// shares with other echoes (see [EchoBeacons.place]).
class EchoBeacon {
  const EchoBeacon(this.node, {required this.lng, required this.lat});

  final TerminalEchoMapNodeEntity node;
  final double lng;
  final double lat;
}

/// Where the airport-zoom hint flies to: the busiest spot near the view.
class EchoHotspot {
  const EchoHotspot({
    required this.lng,
    required this.lat,
    required this.count,
  });

  final double lng;
  final double lat;

  /// Echoes on this spot.
  final int count;
}

/// Echoes drawn at human scale, like people standing in the terminal: a
/// glowing floor disc, only from [showZoom]. Zoomed out further the map
/// shows airports, not echoes.
///
/// A person is a couple of pixels at [showZoom], so the disc keeps a
/// minimum size on screen and settles to its real size in meters as the
/// camera comes closer (from about zoom 19). No column on it: tried, and
/// it read as a tower.
abstract final class EchoBeacons {
  /// Echoes show from this zoom (terminal scale, ~1 m per point).
  static const double showZoom = 16;

  /// They fade in across this step, from just below [showZoom], so the
  /// recenter zoom (exactly 16) never lands on the edge.
  static const double fadeInFrom = showZoom - 0.1;
  static const double fadeInTo = showZoom + 0.2;

  /// Echo coordinates are rounded to ~110 m, so many share one spot. They
  /// stand this far apart there instead, in a sunflower spiral, and read as
  /// a small crowd rather than one pin.
  static const double spacingMeters = 2.5;

  /// The floor disc's radius in points by zoom (the map layer scales it
  /// exponentially between stops): at least 7 points, ~1.2 m once close.
  static const List<(double, double)> discRadius = [
    (16, 7),
    (18, 9),
    (20, 16),
    (22, 64),
  ];

  /// A finger's radius in points: echoes this close to a tap are all hit.
  static const double tapRadiusPoints = 22;

  /// The hint picks among spots this far from the echo nearest the view
  /// center, so it flies to the airport in front of the user.
  static const double hotspotRangeMeters = 1500;

  static const double _metersPerDegreeLat = 111320;
  static const double _earthCircumference = 40075016.686;

  /// Meters one screen point covers at [zoom] and [latitude] (Web Mercator,
  /// 512-point tiles).
  static double metersPerPoint(double zoom, double latitude) =>
      _earthCircumference *
      math.cos(latitude * math.pi / 180) /
      (512 * math.pow(2, zoom));
  static const double _goldenAngle = 2.399963229728653;

  /// Each echo's drawn position. Echoes alone on their spot stay put; on a
  /// shared spot the first (by id, so it never reshuffles) stays in the
  /// middle and the rest spiral out [spacingMeters] apart.
  static List<EchoBeacon> place(List<TerminalEchoMapNodeEntity> nodes) {
    final spots = <(double, double), List<TerminalEchoMapNodeEntity>>{};
    for (final n in nodes) {
      (spots[(n.longitude, n.latitude)] ??= []).add(n);
    }
    return [
      for (final group in spots.values)
        for (final (i, n)
            in ([...group]..sort((a, b) => a.id.compareTo(b.id))).indexed)
          _spiral(n, i),
    ];
  }

  static EchoBeacon _spiral(TerminalEchoMapNodeEntity n, int i) {
    if (i == 0) return EchoBeacon(n, lng: n.longitude, lat: n.latitude);
    final r = spacingMeters * math.sqrt(i);
    final a = i * _goldenAngle;
    final dLat = r * math.sin(a) / _metersPerDegreeLat;
    final dLng = r *
        math.cos(a) /
        (_metersPerDegreeLat * math.cos(n.latitude * math.pi / 180));
    return EchoBeacon(n, lng: n.longitude + dLng, lat: n.latitude + dLat);
  }

  /// The discs (and their tap targets): one point per echo, at its drawn
  /// position, with the pin properties (EchoMapFeatures).
  ///
  /// An echo inside one of the [radar] discs also gets `radarBearing`: its
  /// direction from that disc's center, in degrees clockwise from north
  /// (the sweep's heading), so the map can light it up as the arm passes.
  static Map<String, dynamic> points(
    List<EchoBeacon> beacons, {
    List<RadarDisc> radar = const [],
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final b in beacons) _point(b, radar, at),
      ],
    };
  }

  static Map<String, dynamic> _point(
    EchoBeacon b,
    List<RadarDisc> radar,
    DateTime at,
  ) {
    final feature = EchoMapFeatures.feature(b.node, at, lng: b.lng, lat: b.lat);
    final bearing = radarBearing(b.lng, b.lat, radar);
    if (bearing != null) {
      (feature['properties'] as Map<String, dynamic>)['radarBearing'] = bearing;
    }
    return feature;
  }

  /// A point's direction from the center of the [radar] disc it stands in
  /// (the nearest if several), clockwise from north as the sweep measures
  /// its heading; null outside every disc. Anything on the map the radar
  /// detects (echoes, offers) carries it as `radarBearing`.
  static double? radarBearing(double lng, double lat, List<RadarDisc> radar) {
    RadarDisc? best;
    var bestMeters = double.infinity;
    for (final d in radar) {
      final m = distanceMeters(lng, lat, d.lng, d.lat);
      if (m <= d.radiusKm * 1000 && m < bestMeters) {
        best = d;
        bestMeters = m;
      }
    }
    return best == null
        ? null
        : bearingDeg(lng, lat, fromLng: best.lng, fromLat: best.lat);
  }

  /// Direction of a point from another, degrees clockwise from north
  /// (0..360), as the radar sweep measures its heading.
  static double bearingDeg(
    double lng,
    double lat, {
    required double fromLng,
    required double fromLat,
  }) {
    final east = ((lng - fromLng + 540) % 360 - 180) *
        math.cos((lat + fromLat) / 2 * math.pi / 180);
    final north = lat - fromLat;
    return (math.atan2(east, north) * 180 / math.pi + 360) % 360;
  }

  /// The echoes drawn within [meters] of a point (a tap), nearest first.
  static List<TerminalEchoMapNodeEntity> near(
    List<EchoBeacon> beacons, {
    required double lng,
    required double lat,
    required double meters,
  }) {
    final hits = [
      for (final b in beacons)
        if (distanceMeters(b.lng, b.lat, lng, lat) <= meters)
          (b, distanceMeters(b.lng, b.lat, lng, lat)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final (b, _) in hits) b.node];
  }

  /// Where the airport-zoom hint flies: of the spots within
  /// [hotspotRangeMeters] of the echo nearest the view center, the one with
  /// the most echoes (the nearer one on a tie). Null without echoes.
  static EchoHotspot? hotspot(
    List<TerminalEchoMapNodeEntity> nodes, {
    required double centerLng,
    required double centerLat,
  }) {
    if (nodes.isEmpty) return null;
    final spots = <(double, double), int>{};
    for (final n in nodes) {
      spots.update((n.longitude, n.latitude), (c) => c + 1, ifAbsent: () => 1);
    }
    double fromCenter((double, double) s) =>
        distanceMeters(s.$1, s.$2, centerLng, centerLat);
    final anchor = spots.keys.reduce(
      (a, b) => fromCenter(b) < fromCenter(a) ? b : a,
    );
    final nearby = [
      for (final e in spots.entries)
        if (distanceMeters(e.key.$1, e.key.$2, anchor.$1, anchor.$2) <=
            hotspotRangeMeters)
          e,
    ]..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0
            ? byCount
            : fromCenter(a.key).compareTo(fromCenter(b.key));
      });
    final best = nearby.first;
    return EchoHotspot(lng: best.key.$1, lat: best.key.$2, count: best.value);
  }

  /// Equirectangular distance: exact enough across a terminal or an
  /// airport.
  static double distanceMeters(
    double lng1,
    double lat1,
    double lng2,
    double lat2,
  ) {
    final midLat = (lat1 + lat2) / 2 * math.pi / 180;
    final dLng = ((lng1 - lng2 + 540) % 360 - 180) * math.cos(midLat);
    final dLat = lat1 - lat2;
    return math.sqrt(dLng * dLng + dLat * dLat) * _metersPerDegreeLat;
  }
}
