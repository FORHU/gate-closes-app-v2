import 'dart:math' as math;

/// Which airports can be on screen, for the airports-in-view panel. Mapbox
/// projects points beyond the view, even round the far side of the globe,
/// onto the screen anyway, so the panel checks these first.
abstract final class AirportVisibility {
  /// Whether a point is on the camera's side of the globe, short of the
  /// rim: within [maxAngleDeg] of the view center.
  static bool facesCamera({
    required double lat,
    required double lng,
    required double centerLat,
    required double centerLng,
    double maxAngleDeg = 75,
  }) {
    double rad(double d) => d * math.pi / 180;
    final cosAngle = math.sin(rad(lat)) * math.sin(rad(centerLat)) +
        math.cos(rad(lat)) *
            math.cos(rad(centerLat)) *
            math.cos(rad(lng - centerLng));
    return cosAngle > math.cos(rad(maxAngleDeg));
  }

  /// How far from the view center (degrees of arc) a point can still be on
  /// screen at [zoom]: the screen's half diagonal on the ground, tripled
  /// for the tilt, never past the globe's rim (75). Mapbox projects points
  /// beyond it, even round the far side, onto the screen anyway: an airport
  /// in New York got a label over Luzon at zoom 7.
  static double viewAngleDeg(double zoom, {required double halfDiagonal}) {
    const metersPerDegree = 111320;
    final metersPerPoint = 40075016.686 / (512 * math.pow(2, zoom));
    return math.min(
      75,
      3 * halfDiagonal * metersPerPoint / metersPerDegree,
    );
  }
}
