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

  group('AirportRadar.centers', () {
    test('one point per disc, at its center', () {
      const bag = RadarDisc(lng: 120.62, lat: 16.375, radiusKm: 8);
      const mnl = RadarDisc(lng: 121.02, lat: 14.51, radiusKm: 15);
      final features = _features(AirportRadar.centers([bag, mnl]));
      expect(features, hasLength(2));
      final g = features.last['geometry'] as Map<String, dynamic>;
      expect(g['type'], 'Point');
      expect(g['coordinates'], [121.02, 14.51]);
    });

    test('nothing to draw without discs', () {
      expect(AirportRadar.centers(const [])['features'], isEmpty);
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
    const disc = RadarDisc(lng: 0, lat: 0, radiusKm: 10);
    final bands = AirportRadar.beamBands.length;

    List<Map<String, dynamic>> pieces(double heading) => [
          for (final f in _features(AirportRadar.sweep([disc], heading)))
            if ((f['geometry'] as Map)['type'] == 'Polygon') f,
        ];

    test('a banded slice fan plus one beam line per disc', () {
      final features = _features(AirportRadar.sweep([disc, disc], 90));
      expect(
        features,
        hasLength(2 * (AirportRadar.sweepSlices * bands + 1)),
      );
    });

    test('fades behind the heading and out from the center', () {
      final features = pieces(90);
      double alpha(int slice, int band) =>
          _prop(features[slice * bands + band], 'alpha')! as double;

      expect(alpha(0, 0), 1);
      for (var b = 0; b < bands; b++) {
        for (var s = 1; s < AirportRadar.sweepSlices; s++) {
          expect(alpha(s, b), lessThan(alpha(s - 1, b)));
        }
      }
      for (var s = 0; s < AirportRadar.sweepSlices; s++) {
        for (var b = 1; b < bands; b++) {
          expect(alpha(s, b), lessThan(alpha(s, b - 1)));
        }
      }
    });

    test('the leading slice ends at the heading', () {
      // The outer band's arc runs from the slice start to its end; the end
      // point is due east at 90°, at the rim.
      final outer = _coords(pieces(90)[bands - 1]);
      final arcEnd = outer[2];
      expect(arcEnd[1], closeTo(0, 1e-9));
      expect(arcEnd[0], greaterThan(0));
    });

    test('the beam runs from the center to the rim at the heading', () {
      final beam = _features(AirportRadar.sweep([disc], 0)).last;
      expect(_prop(beam, 'kind'), 'beam');
      final line = _coords(beam);
      expect(line.first, [0, 0]);
      // Due north: same longitude, 10 km up (to ~1 m rounding).
      expect(line.last[0], closeTo(0, 1e-9));
      expect(line.last[1] * 110.574, closeTo(10, 0.002));
    });

    test('nothing to sweep without discs', () {
      expect(AirportRadar.sweep(const [], 0)['features'], isEmpty);
    });
  });
}
