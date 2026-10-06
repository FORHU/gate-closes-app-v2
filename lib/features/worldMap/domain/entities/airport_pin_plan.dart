import 'package:gate_closes/features/worldMap/domain/entities/airport_boundary_index.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';

/// What the map shows for a view.
enum MapPinMode {
  /// Zoomed out: one count bubble per airport.
  counts,

  /// Zoomed in on airports: their echo pins.
  pins,
}

/// Decides, for one view, whether the map shows per-airport counts or pins,
/// and whose pins to load. Echoes only exist inside an airport's radius, so
/// pins are fetched per airport (`?airport=MNL`) instead of per view.
class AirportPinPlan {
  const AirportPinPlan._(this.mode, this.airports);

  factory AirportPinPlan.forView({
    required List<AirportEchoCount> counts,
    required double west,
    required double south,
    required double east,
    required double north,
    required double zoom,
    required double centerLng,
    required double centerLat,
  }) {
    if (zoom < pinsMinZoom) {
      return const AirportPinPlan._(MapPinMode.counts, []);
    }
    final minLat = south - marginDegrees;
    final maxLat = north + marginDegrees;
    // Widen by the margin on each side; `west > east` crosses the
    // antimeridian. A view this wide already shows every longitude.
    final width = west <= east ? east - west : east - west + 360;
    final allLng = width + 2 * marginDegrees >= 360;
    final w = _wrap(west - marginDegrees);
    final e = _wrap(east + marginDegrees);
    bool lngHit(double lng) =>
        allLng || (w <= e ? lng >= w && lng <= e : lng >= w || lng <= e);

    final inView = [
      for (final c in counts)
        if (c.count > 0 &&
            c.latitude >= minLat &&
            c.latitude <= maxLat &&
            lngHit(c.longitude))
          c,
    ]..sort(
        (a, b) => _distance(a, centerLng, centerLat)
            .compareTo(_distance(b, centerLng, centerLat)),
      );
    return AirportPinPlan._(
      MapPinMode.pins,
      [for (final c in inView.take(maxAirports)) c.airportIata],
    );
  }

  /// Pins from the zoom where airport circles appear; below it the map
  /// shows only the airport heat clouds.
  static const double pinsMinZoom = AirportBoundaryIndex.minZoom;

  /// An airport just outside the view still has echoes inside it (radii go
  /// up to a few dozen km), so the view is widened by about 55 km.
  static const double marginDegrees = 0.5;

  /// Most airports whose pins load at once, nearest the view center first.
  static const int maxAirports = 8;

  final MapPinMode mode;

  /// Airport codes whose pins to show; empty in [MapPinMode.counts].
  final List<String> airports;

  static double _wrap(double lng) => (lng + 180) % 360 - 180;

  /// Squared degrees, longitude taken the short way round: only for ordering.
  static double _distance(AirportEchoCount c, double lng, double lat) {
    final dLng = ((c.longitude - lng + 540) % 360) - 180;
    final dLat = c.latitude - lat;
    return dLng * dLng + dLat * dLat;
  }
}
