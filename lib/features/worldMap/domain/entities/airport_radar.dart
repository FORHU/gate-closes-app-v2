import 'dart:math' as math;

/// One airport boundary circle: its center and radius.
class RadarDisc {
  const RadarDisc({
    required this.lng,
    required this.lat,
    required this.radiusKm,
  });

  final double lng;
  final double lat;
  final double radiusKm;
}

/// Radar decoration for the airport boundary circles: inner rings, spokes
/// and edge ticks ([grid]) plus a rotating sweep beam ([sweep]).
///
/// Boundaries are circles built server-side (turf.circle around the airport
/// at `radiusKm`), so each polygon's center and radius are recovered from its
/// ring. Distances use a local flat-earth approximation, accurate to well
/// under 1% at airport scale (≤ ~20 km).
class AirportRadar {
  AirportRadar._();

  static const _kmPerDegLat = 110.574;
  static const _kmPerDegLngAtEquator = 111.32;

  /// Inner rings, as fractions of the radius.
  static const ringFractions = [0.25, 0.5, 0.75];
  static const spokeCount = 12;

  /// One tick every 5°; every 30° is a major (longer) tick.
  static const tickCount = 72;

  /// Width of the beam and how many slices it fades over.
  static const sweepWidthDeg = 48.0;
  static const sweepSlices = 8;

  /// Points per drawn circle/arc segment.
  static const _circleSegments = 48;

  /// Centers and radii of the Polygon features in a boundary
  /// FeatureCollection. Non-polygons and degenerate rings are skipped.
  static List<RadarDisc> discs(Map<String, dynamic>? boundaries) {
    final features = boundaries?['features'];
    if (features is! List) return const [];
    final discs = <RadarDisc>[];
    for (final f in features) {
      if (f is! Map) continue;
      final disc = _disc(f['geometry']);
      if (disc != null) discs.add(disc);
    }
    return discs;
  }

  /// The [count] discs closest to ([lng], [lat]), closest first.
  static List<RadarDisc> nearest(
    List<RadarDisc> discs, {
    required double lng,
    required double lat,
    required int count,
  }) {
    final cosLat = math.cos(lat * math.pi / 180);
    double distance(RadarDisc d) {
      // Shortest way around in longitude, so the antimeridian is handled.
      final dLng = ((d.lng - lng + 540) % 360 - 180) * cosLat;
      final dLat = d.lat - lat;
      return dLng * dLng + dLat * dLat;
    }

    final sorted = [...discs]
      ..sort((a, b) => distance(a).compareTo(distance(b)));
    return sorted.take(count).toList();
  }

  /// Rings, spokes and ticks for every disc: one MultiLineString per `kind`
  /// (`ring`, `spoke`, `tick`, `tickMajor`) per disc, to keep the payload
  /// sent to the map small.
  static Map<String, dynamic> grid(List<RadarDisc> discs) {
    final features = <Map<String, dynamic>>[];
    for (final d in discs) {
      final rings = [
        for (final f in ringFractions) _arc(d, d.radiusKm * f, 0, 360),
      ];
      final spokes = [
        for (var i = 0; i < spokeCount; i++)
          [
            [d.lng, d.lat],
            _offset(d, d.radiusKm, i * 360 / spokeCount),
          ],
      ];
      final ticks = <List<List<double>>>[];
      final majorTicks = <List<List<double>>>[];
      for (var i = 0; i < tickCount; i++) {
        final bearing = i * 360 / tickCount;
        final major = i % (tickCount ~/ spokeCount) == 0;
        final inner = d.radiusKm * (major ? 0.88 : 0.94);
        (major ? majorTicks : ticks).add([
          _offset(d, inner, bearing),
          _offset(d, d.radiusKm, bearing),
        ]);
      }
      features
        ..add(_lines('ring', rings))
        ..add(_lines('spoke', spokes))
        ..add(_lines('tick', ticks))
        ..add(_lines('tickMajor', majorTicks));
    }
    return _collection(features);
  }

  /// The beam at [headingDeg] (clockwise from north) for every disc: a fan of
  /// [sweepSlices] wedges trailing behind the heading, each with an `alpha`
  /// from 1 (leading edge) down toward 0.
  static Map<String, dynamic> sweep(List<RadarDisc> discs, double headingDeg) {
    final features = <Map<String, dynamic>>[];
    const sliceDeg = sweepWidthDeg / sweepSlices;
    for (final d in discs) {
      for (var i = 0; i < sweepSlices; i++) {
        final end = headingDeg - i * sliceDeg;
        final start = end - sliceDeg;
        final ring = <List<double>>[
          [d.lng, d.lat],
          ..._arc(d, d.radiusKm, start, end, segments: 4),
          [d.lng, d.lat],
        ];
        features.add({
          'type': 'Feature',
          'properties': {'alpha': 1 - i / sweepSlices},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [ring],
          },
        });
      }
    }
    return _collection(features);
  }

  static RadarDisc? _disc(Object? geometry) {
    if (geometry is! Map || geometry['type'] != 'Polygon') return null;
    final rings = geometry['coordinates'];
    if (rings is! List || rings.isEmpty || rings.first is! List) return null;
    final points = <List<double>>[];
    for (final p in rings.first as List) {
      if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
        points.add([(p[0] as num).toDouble(), (p[1] as num).toDouble()]);
      }
    }
    // A closed ring repeats its first point; don't count it twice.
    if (points.length > 1 &&
        points.first[0] == points.last[0] &&
        points.first[1] == points.last[1]) {
      points.removeLast();
    }
    if (points.length < 3) return null;
    var lng = 0.0;
    var lat = 0.0;
    for (final p in points) {
      lng += p[0];
      lat += p[1];
    }
    lng /= points.length;
    lat /= points.length;
    final kmPerDegLng = _kmPerDegLngAtEquator * math.cos(lat * math.pi / 180);
    var radius = 0.0;
    for (final p in points) {
      final dx = (p[0] - lng) * kmPerDegLng;
      final dy = (p[1] - lat) * _kmPerDegLat;
      radius += math.sqrt(dx * dx + dy * dy);
    }
    radius /= points.length;
    if (radius <= 0) return null;
    return RadarDisc(lng: lng, lat: lat, radiusKm: radius);
  }

  /// The point [km] from the disc center at [bearingDeg] (clockwise from
  /// north), as `[lng, lat]`.
  static List<double> _offset(RadarDisc d, double km, double bearingDeg) {
    final b = bearingDeg * math.pi / 180;
    final kmPerDegLng = _kmPerDegLngAtEquator * math.cos(d.lat * math.pi / 180);
    return [
      _round(d.lng + km * math.sin(b) / kmPerDegLng),
      _round(d.lat + km * math.cos(b) / _kmPerDegLat),
    ];
  }

  /// 5 decimals is about 1 m: plenty for drawing, and a shorter payload.
  static double _round(double v) => (v * 1e5).roundToDouble() / 1e5;

  static List<List<double>> _arc(
    RadarDisc d,
    double km,
    double fromDeg,
    double toDeg, {
    int segments = _circleSegments,
  }) =>
      [
        for (var i = 0; i <= segments; i++)
          _offset(d, km, fromDeg + (toDeg - fromDeg) * i / segments),
      ];

  static Map<String, dynamic> _lines(
    String kind,
    List<List<List<double>>> lines,
  ) =>
      {
        'type': 'Feature',
        'properties': {'kind': kind},
        'geometry': {'type': 'MultiLineString', 'coordinates': lines},
      };

  static Map<String, dynamic> _collection(List<Map<String, dynamic>> f) => {
        'type': 'FeatureCollection',
        'features': f,
      };
}
