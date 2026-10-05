/// The visible map rectangle, normalized for the API and boundary lookup.
///
/// Mapbox reports a view crossing the antimeridian with unwrapped
/// longitudes (e.g. east = 200), and a zoomed-out globe can span more than
/// 360°. The API only accepts -180..180, so longitudes are wrapped into that
/// range: a view crossing the antimeridian comes out as `west > east`, and a
/// view at least 360° wide becomes the whole world.
///
/// On a globe, Mapbox can also report a crossing view with its edges
/// already wrapped and flipped (sw = -122, ne = 114 for a Pacific view), which
/// reads as the opposite side of the world. Given the camera's `centerLng`,
/// a view that doesn't contain its own center is swapped back.
class MapViewBounds {
  const MapViewBounds._(this.west, this.south, this.east, this.north);

  factory MapViewBounds.normalize({
    required double west,
    required double south,
    required double east,
    required double north,
    double? centerLng,
  }) {
    final s = south.clamp(-90.0, 90.0);
    final n = north.clamp(-90.0, 90.0);
    if (east - west >= 360) return MapViewBounds._(-180, s, 180, n);
    final w = _wrap(west);
    final e = _wrap(east);
    if (centerLng != null && !_contains(w, e, _wrap(centerLng))) {
      return MapViewBounds._(e, s, w, n);
    }
    return MapViewBounds._(w, s, e, n);
  }

  final double west;
  final double south;
  final double east;
  final double north;

  /// Whether [lng] lies in the view from [west] east to [east].
  static bool _contains(double west, double east, double lng) =>
      west <= east ? lng >= west && lng <= east : lng >= west || lng <= east;

  /// Wraps a longitude into -180..180, keeping exactly 180 as 180.
  static double _wrap(double lng) {
    if (lng >= -180 && lng <= 180) return lng;
    final wrapped = ((lng + 180) % 360 + 360) % 360 - 180;
    return wrapped == -180 && lng > 0 ? 180 : wrapped;
  }
}
