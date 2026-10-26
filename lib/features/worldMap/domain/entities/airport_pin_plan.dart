import 'package:gate_closes/features/worldMap/domain/entities/airport_boundary_index.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_point.dart';

/// What the map shows for a view.
enum MapPinMode {
  /// Zoomed out: one count bubble per airport.
  counts,

  /// Zoomed in on airports: their echo pins.
  pins,
}

/// Decides, for one view, whether the map shows per-airport counts or pins,
/// and whose pins and offers to load. Echoes and offers only exist inside
/// an airport's radius, so both are fetched per airport (`?airport=MNL`)
/// instead of per view.
class AirportPinPlan {
  const AirportPinPlan._(this.mode, this.airports, this.offerAirports);

  /// [allAirports] is every airport the map knows: offers don't need
  /// echoes, so they are planned from it. Until it loads, offers follow the
  /// echo airports.
  factory AirportPinPlan.forView({
    required List<AirportEchoCount> counts,
    required double west,
    required double south,
    required double east,
    required double north,
    required double zoom,
    required double centerLng,
    required double centerLat,
    List<AirportPoint> allAirports = const [],
  }) {
    if (zoom < pinsMinZoom) {
      return const AirportPinPlan._(MapPinMode.counts, <String>[], <String>[]);
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

    /// The codes of [points] in view, nearest the center first.
    List<String> nearest(Iterable<(String, double, double)> points) {
      final inView = [
        for (final p in points)
          if (p.$3 >= minLat && p.$3 <= maxLat && lngHit(p.$2)) p,
      ]..sort(
          (a, b) => _distance(a.$2, a.$3, centerLng, centerLat)
              .compareTo(_distance(b.$2, b.$3, centerLng, centerLat)),
        );
      return [for (final p in inView.take(maxAirports)) p.$1];
    }

    final echoAirports = nearest([
      for (final c in counts)
        if (c.count > 0) (c.airportIata, c.longitude, c.latitude),
    ]);
    return AirportPinPlan._(
      MapPinMode.pins,
      echoAirports,
      allAirports.isEmpty
          ? echoAirports
          : nearest([
              for (final a in allAirports) (a.iata, a.longitude, a.latitude),
            ]),
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

  /// Airport codes whose offers to show, echoes or not; empty in
  /// [MapPinMode.counts].
  final List<String> offerAirports;

  static double _wrap(double lng) => (lng + 180) % 360 - 180;

  /// Squared degrees, longitude taken the short way round: only for ordering.
  static double _distance(double lng, double lat, double toLng, double toLat) {
    final dLng = ((lng - toLng + 540) % 360) - 180;
    final dLat = lat - toLat;
    return dLng * dLng + dLat * dLat;
  }
}
