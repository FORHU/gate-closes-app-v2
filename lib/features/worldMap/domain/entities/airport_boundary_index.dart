import 'dart:math' as math;

/// All airport boundary polygons, with a bounding box per feature, so the map
/// only ever receives the few that are on screen.
///
/// Pushing the whole worldwide collection into one Mapbox source crashed
/// Android with an out-of-memory error: the plugin serializes the entire
/// FeatureCollection into a single JSON string on the Java heap. Airport
/// polygons are invisible when zoomed out anyway.
class AirportBoundaryIndex {
  AirportBoundaryIndex._(this._entries);

  /// Builds the index from the API's FeatureCollection. Features without a
  /// usable Polygon geometry are skipped.
  factory AirportBoundaryIndex.fromGeoJson(Map<String, dynamic>? geoJson) {
    final features = geoJson?['features'];
    final entries = <_Entry>[];
    if (features is List) {
      for (final f in features) {
        if (f is! Map) continue;
        final box = _bbox(f['geometry']);
        if (box != null) {
          entries.add(_Entry(f.cast<String, dynamic>(), box));
        }
      }
    }
    return AirportBoundaryIndex._(entries);
  }

  static final empty = AirportBoundaryIndex._(const []);

  /// Below this zoom the map shows only the airport heat clouds: no
  /// polygons, no pins (device test: 10 must still be cloud).
  static const double minZoom = 10.5;

  /// Upper bound per update, in case a very wide view at [minZoom] still
  /// covers a dense region.
  static const int maxFeatures = 300;

  final List<_Entry> _entries;

  int get length => _entries.length;

  /// A FeatureCollection of the boundaries overlapping the view. Handles a
  /// view that crosses the antimeridian (`west > east`).
  Map<String, dynamic> visible({
    required double west,
    required double south,
    required double east,
    required double north,
    required double zoom,
  }) {
    final features = <Map<String, dynamic>>[];
    if (zoom >= minZoom) {
      final wraps = west > east;
      for (final e in _entries) {
        final b = e.box;
        final latHit = b.minLat <= north && b.maxLat >= south;
        final lngHit = wraps
            ? (b.maxLng >= west || b.minLng <= east)
            : (b.minLng <= east && b.maxLng >= west);
        if (latHit && lngHit) {
          features.add(e.feature);
          if (features.length >= maxFeatures) break;
        }
      }
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  static _Box? _bbox(Object? geometry) {
    if (geometry is! Map || geometry['type'] != 'Polygon') return null;
    final rings = geometry['coordinates'];
    if (rings is! List) return null;
    var minLng = double.infinity;
    var minLat = double.infinity;
    var maxLng = double.negativeInfinity;
    var maxLat = double.negativeInfinity;
    for (final ring in rings) {
      if (ring is! List) continue;
      for (final point in ring) {
        if (point is! List || point.length < 2) continue;
        final lng = point[0];
        final lat = point[1];
        if (lng is! num || lat is! num) continue;
        minLng = math.min(minLng, lng.toDouble());
        maxLng = math.max(maxLng, lng.toDouble());
        minLat = math.min(minLat, lat.toDouble());
        maxLat = math.max(maxLat, lat.toDouble());
      }
    }
    if (minLng == double.infinity) return null;
    return _Box(minLng, minLat, maxLng, maxLat);
  }
}

class _Entry {
  const _Entry(this.feature, this.box);
  final Map<String, dynamic> feature;
  final _Box box;
}

class _Box {
  const _Box(this.minLng, this.minLat, this.maxLng, this.maxLat);
  final double minLng;
  final double minLat;
  final double maxLng;
  final double maxLat;
}
