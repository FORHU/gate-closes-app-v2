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

/// Radar decoration for the airport boundary circles, drawn like an
/// airport's rotating beacon: a glowing [centers] point and a soft cone of
/// light ([sweep]) turning from it, bright near the middle and fading to
/// nothing at the edge.
///
/// Boundaries are circles built server-side (turf.circle around the airport
/// at `radiusKm`), so each polygon's center and radius are recovered from its
/// ring. Distances use a local flat-earth approximation, accurate to well
/// under 1% at airport scale (≤ ~20 km).
class AirportRadar {
  AirportRadar._();

  static const _kmPerDegLat = 110.574;
  static const _kmPerDegLngAtEquator = 111.32;

  /// Width of the beam and how many slices it fades over.
  static const sweepWidthDeg = 70.0;
  static const sweepSlices = 12;

  /// The beam's distance bands, as the outer edge of each (a fraction of the
  /// radius), and each band's brightness: bright center, faint edge.
  static const beamBands = [0.3, 0.55, 0.8, 1.0];
  static const bandAlpha = [1.0, 0.7, 0.42, 0.18];

  /// Points per slice arc: a slice is under 6°, so 2 segments are smooth.
  static const _sliceSegments = 2;

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

  /// The beacon's center for every disc, one Point each.
  static Map<String, dynamic> centers(List<RadarDisc> discs) => _collection([
        for (final d in discs)
          {
            'type': 'Feature',
            'properties': {'kind': 'center'},
            'geometry': {
              'type': 'Point',
              'coordinates': [d.lng, d.lat],
            },
          },
      ]);

  /// The beam at [headingDeg] (clockwise from north) for every disc: a fan of
  /// [sweepSlices] slices trailing behind the heading, each split into the
  /// [beamBands] from the center out. Each piece's `alpha` fades with the
  /// slice (1 at the leading edge) and with the band (bright center, faint
  /// edge). Plus a `beam` line from the center to the rim at the heading.
  static Map<String, dynamic> sweep(List<RadarDisc> discs, double headingDeg) {
    final features = <Map<String, dynamic>>[];
    const sliceDeg = sweepWidthDeg / sweepSlices;
    for (final d in discs) {
      for (var i = 0; i < sweepSlices; i++) {
        final end = headingDeg - i * sliceDeg;
        final start = end - sliceDeg;
        final fade = math.pow(1 - i / sweepSlices, 1.7).toDouble();
        for (var j = 0; j < beamBands.length; j++) {
          final inner = j == 0 ? 0.0 : d.radiusKm * beamBands[j - 1];
          features.add({
            'type': 'Feature',
            'properties': {'alpha': fade * bandAlpha[j]},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                _sector(d, inner, d.radiusKm * beamBands[j], start, end),
              ],
            },
          });
        }
      }
      features.add({
        'type': 'Feature',
        'properties': {'kind': 'beam'},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [d.lng, d.lat],
            _offset(d, d.radiusKm, headingDeg),
          ],
        },
      });
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

  /// A closed ring between [innerKm] and [outerKm] from [fromDeg] to
  /// [toDeg]: a wedge from the center when [innerKm] is 0.
  static List<List<double>> _sector(
    RadarDisc d,
    double innerKm,
    double outerKm,
    double fromDeg,
    double toDeg,
  ) {
    final outer = _arc(d, outerKm, fromDeg, toDeg, segments: _sliceSegments);
    return [
      ...outer,
      if (innerKm > 0)
        ..._arc(d, innerKm, toDeg, fromDeg, segments: _sliceSegments)
      else
        [d.lng, d.lat],
      outer.first,
    ];
  }

  static List<List<double>> _arc(
    RadarDisc d,
    double km,
    double fromDeg,
    double toDeg, {
    required int segments,
  }) =>
      [
        for (var i = 0; i <= segments; i++)
          _offset(d, km, fromDeg + (toDeg - fromDeg) * i / segments),
      ];

  static Map<String, dynamic> _collection(List<Map<String, dynamic>> f) => {
        'type': 'FeatureCollection',
        'features': f,
      };
}
