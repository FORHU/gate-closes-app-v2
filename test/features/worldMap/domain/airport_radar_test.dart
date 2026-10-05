import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_radar.dart';

/// A closed circle polygon like the API's turf.circle boundaries.
Map<String, dynamic> _circle(double lng, double lat, double km) {
  final kmPerDegLng = 111.32 * math.cos(lat * math.pi / 180);
  final ring = <List<double>>[
    for (var i = 0; i < 32; i++)
      [
        lng + km * math.sin(i * 2 * math.pi / 32) / kmPerDegLng,
        lat + km * math.cos(i * 2 * math.pi / 32) / 110.574,
      ],
  ];
  ring.add(ring.first);
  return {
    'type': 'Feature',
    'geometry': {
      'type': 'Polygon',
      'coordinates': [ring],
    },
  };
}

Map<String, dynamic> _collection(List<Map<String, dynamic>> f) => {
      'type': 'FeatureCollection',
      'features': f,
    };

List<Map<String, dynamic>> _features(Map<String, dynamic> fc) =>
    (fc['features'] as List).cast<Map<String, dynamic>>();

Object? _prop(Map<String, dynamic> f, String key) =>
    (f['properties'] as Map<String, dynamic>)[key];

/// A LineString's points, or a Polygon's outer ring.
List<List<double>> _coords(Map<String, dynamic> f) {
  final g = f['geometry'] as Map<String, dynamic>;
  final c = g['coordinates'] as List;
  final points = g['type'] == 'Polygon' ? c.first as List : c;
  return [for (final p in points) (p as List).cast<double>()];
}

/// The lines of a MultiLineString feature.
List<List<List<double>>> _lines(Map<String, dynamic> f) {
  final g = f['geometry'] as Map<String, dynamic>;
  expect(g['type'], 'MultiLineString');
  return [
    for (final line in g['coordinates'] as List)
      [for (final p in line as List) (p as List).cast<double>()],
  ];
}

void main() {
  group('AirportRadar.discs', () {
    test('recovers center and radius from a boundary circle', () {
      // Loakan (BAG): 8 km circle.
      final discs = AirportRadar.discs(
        _collection([_circle(120.62, 16.375, 8)]),
      );
      expect(discs, hasLength(1));
      expect(discs.single.lng, closeTo(120.62, 1e-6));
      expect(discs.single.lat, closeTo(16.375, 1e-6));
      expect(discs.single.radiusKm, closeTo(8, 0.01));
    });

    test('skips non-polygons, degenerate rings and junk', () {
      final discs = AirportRadar.discs(
        _collection([
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [1, 2],
            },
          },
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [0, 0],
                  [0, 0],
                ],
              ],
            },
          },
        ]),
      );
      expect(discs, isEmpty);
      expect(AirportRadar.discs(null), isEmpty);
    });
  });

  group('AirportRadar.grid', () {
    test('one feature per kind per disc, with every line in it', () {
      const disc = RadarDisc(lng: 120.62, lat: 16.375, radiusKm: 8);
      final features = _features(AirportRadar.grid([disc, disc]));
      expect(features, hasLength(2 * 4));

      int lines(String kind) => features
          .where((f) => _prop(f, 'kind') == kind)
          .map((f) => _lines(f).length)
          .reduce((a, b) => a + b);

      expect(lines('ring'), 2 * AirportRadar.ringFractions.length);
      expect(lines('spoke'), 2 * AirportRadar.spokeCount);
      expect(lines('tickMajor'), 2 * AirportRadar.spokeCount);
      expect(
        lines('tick'),
        2 * (AirportRadar.tickCount - AirportRadar.spokeCount),
      );
    });

    test('spokes reach the edge of the circle', () {
      const disc = RadarDisc(lng: 120.62, lat: 16.375, radiusKm: 8);
      final features = _features(AirportRadar.grid([disc]));
      final spokes = features.firstWhere((f) => _prop(f, 'kind') == 'spoke');
      final end = _lines(spokes).first.last;
      // Bearing 0 is due north: same longitude, 8 km up (to ~1 m rounding).
      expect(end[0], closeTo(120.62, 1e-5));
      expect((end[1] - 16.375) * 110.574, closeTo(8, 0.002));
    });

    test('nothing to draw without discs', () {
      expect(AirportRadar.grid(const [])['features'], isEmpty);
    });
  });

  group('AirportRadar.nearest', () {
    test('keeps the closest discs to the view center, closest first', () {
      const far = RadarDisc(lng: 125, lat: 10, radiusKm: 15);
      const near = RadarDisc(lng: 121, lat: 14.5, radiusKm: 15);
      const mid = RadarDisc(lng: 120.6, lat: 16.4, radiusKm: 8);
      final picked = AirportRadar.nearest(
        [far, mid, near],
        lng: 121,
        lat: 14.6,
        count: 2,
      );
      expect(picked, [near, mid]);
    });

    test('measures across the antimeridian the short way', () {
      const west = RadarDisc(lng: 179.9, lat: 0, radiusKm: 10);
      const east = RadarDisc(lng: -170, lat: 0, radiusKm: 10);
      final picked = AirportRadar.nearest(
        [east, west],
        lng: -179.9,
        lat: 0,
        count: 1,
      );
      expect(picked, [west]);
    });
  });

  group('AirportRadar.sweep', () {
    test('fans slices behind the heading, fading out', () {
      const disc = RadarDisc(lng: 0, lat: 0, radiusKm: 10);
      final features = _features(AirportRadar.sweep([disc], 90));
      expect(features, hasLength(AirportRadar.sweepSlices));

      final alphas = [
        for (final f in features) _prop(f, 'alpha')! as double,
      ];
      expect(alphas.first, 1);
      for (var i = 1; i < alphas.length; i++) {
        expect(alphas[i], lessThan(alphas[i - 1]));
      }

      // The leading slice ends at the heading (due east at 90°).
      final lead = _coords(features.first);
      final edge = lead[lead.length - 2];
      expect(edge[1], closeTo(0, 1e-9));
      expect(edge[0], greaterThan(0));
    });

    test('nothing to sweep without discs', () {
      expect(AirportRadar.sweep(const [], 0)['features'], isEmpty);
    });
  });
}
