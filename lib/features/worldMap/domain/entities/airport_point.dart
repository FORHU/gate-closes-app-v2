import 'package:equatable/equatable.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';

/// Every airport the map knows (from the airport circles), as one point:
/// zoomed out, the airports without echoes get a quiet dot and name next
/// to the busy ones' glow and tags.
class AirportPoint extends Equatable {
  const AirportPoint({
    required this.iata,
    required this.name,
    required this.longitude,
    required this.latitude,
  });

  final String iata;
  final String name;
  final double longitude;
  final double latitude;

  /// One point per airport circle in [geoJson] (`GET /airport/geojson`):
  /// the circle's center, its `iata` and `airport` name. Features without
  /// a code or a usable ring are skipped.
  static List<AirportPoint> fromBoundaries(Map<String, dynamic>? geoJson) {
    final features = geoJson?['features'];
    if (features is! List) return const [];
    return [
      for (final f in features)
        if (_point(f) case final p?) p,
    ];
  }

  static AirportPoint? _point(Object? feature) {
    if (feature is! Map) return null;
    final props = feature['properties'];
    final iata = props is Map ? props['iata']?.toString().trim() : null;
    if (iata == null || iata.isEmpty) return null;
    final geometry = feature['geometry'];
    if (geometry is! Map || geometry['type'] != 'Polygon') return null;
    final rings = geometry['coordinates'];
    if (rings is! List || rings.isEmpty || rings.first is! List) return null;
    var lng = 0.0;
    var lat = 0.0;
    var n = 0;
    final ring = rings.first as List;
    // A closed ring repeats its first point; don't count it twice.
    final last = ring.length > 1 && _same(ring.first, ring.last)
        ? ring.length - 1
        : ring.length;
    for (var i = 0; i < last; i++) {
      final p = ring[i];
      if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
        lng += (p[0] as num).toDouble();
        lat += (p[1] as num).toDouble();
        n++;
      }
    }
    if (n == 0) return null;
    final name = props is Map ? props['airport']?.toString().trim() : null;
    return AirportPoint(
      iata: iata,
      name: name == null || name.isEmpty ? iata : name,
      longitude: lng / n,
      latitude: lat / n,
    );
  }

  static bool _same(Object? a, Object? b) =>
      a is List &&
      b is List &&
      a.length >= 2 &&
      b.length >= 2 &&
      a[0] == b[0] &&
      a[1] == b[1];

  /// The airports in [all] with no echoes in [counts], as the GeoJSON the
  /// quiet dots and names render: `iata`, and `name` without "(International)
  /// Airport", in capitals.
  static Map<String, dynamic> quietCollection(
    List<AirportPoint> all,
    List<AirportEchoCount> counts,
  ) {
    final busy = {
      for (final c in counts)
        if (c.count > 0) c.airportIata,
    };
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final a in all)
          if (!busy.contains(a.iata))
            {
              'type': 'Feature',
              'id': a.iata,
              'geometry': {
                'type': 'Point',
                'coordinates': [a.longitude, a.latitude],
              },
              'properties': {
                'iata': a.iata,
                'name': shortName(a.name),
              },
            },
      ],
    };
  }

  /// "Ninoy Aquino International Airport" → "NINOY AQUINO".
  static String shortName(String name) => name
      .replaceAll(
        RegExp(r'\s+(International\s+)?Airport$', caseSensitive: false),
        '',
      )
      .toUpperCase();

  @override
  List<Object?> get props => [iata, name, longitude, latitude];
}
