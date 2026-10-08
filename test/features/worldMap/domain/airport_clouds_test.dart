import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_clouds.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_beacons.dart';

const mnl = AirportEchoCount(
  airportIata: 'MNL',
  count: 12,
  latitude: 14.51,
  longitude: 121.02,
);

List<List<double>> points(double zoom) => [
      for (final f
          in (AirportClouds.collection([mnl], zoom: zoom)['features'] as List)
              .cast<Map<String, dynamic>>())
        [
          for (final v in (f['geometry'] as Map)['coordinates'] as List)
            (v as num).toDouble(),
        ],
    ];

void main() {
  test('each airport becomes a cluster of puffs, one on the airport', () {
    final p = points(6);
    expect(p, hasLength(AirportClouds.puffs + 1));
    expect(p.first, [121.02, 14.51]);
  });

  test('the pattern is the same every time (seeded by the code)', () {
    expect(points(6), points(6));
  });

  test('puffs stay within the spread, measured in points', () {
    const zoom = 6.0;
    final perPoint = EchoBeacons.metersPerPoint(zoom, 14.51);
    final maxMeters = AirportClouds.spreadPoints *
        AirportClouds.zoomScale(zoom) *
        mnl.cloudScale *
        AirportClouds.stretchX *
        perPoint;
    for (final q in points(zoom)) {
      final m = EchoBeacons.distanceMeters(q[0], q[1], 121.02, 14.51);
      expect(m, lessThanOrEqualTo(maxMeters + 1));
    }
  });

  test('zooming in pulls the puffs closer on the ground', () {
    double far(double zoom) => points(zoom)
        .map((q) => EchoBeacons.distanceMeters(q[0], q[1], 121.02, 14.51))
        .reduce((a, b) => a > b ? a : b);
    final scale = AirportClouds.zoomScale(8) / AirportClouds.zoomScale(6);
    expect(far(8), closeTo(far(6) / 4 * scale, far(6) * 0.01));
  });

  test('clouds are tight zoomed out and full size by the airport zoom', () {
    expect(AirportClouds.zoomScale(2), closeTo(0.35, 1e-9));
    expect(AirportClouds.zoomScale(5), lessThan(AirportClouds.zoomScale(8)));
    expect(AirportClouds.zoomScale(10), 1);
  });

  test('the puffs share the airport heat', () {
    final features =
        (AirportClouds.collection([mnl], zoom: 6)['features'] as List)
            .cast<Map<String, dynamic>>();
    for (final f in features) {
      final props = f['properties'] as Map;
      expect(props['airportIata'], 'MNL');
      expect(props['heatWeight'] as double, lessThan(mnl.heatWeight));
    }
  });
}
