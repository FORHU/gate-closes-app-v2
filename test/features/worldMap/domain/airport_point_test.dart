import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_point.dart';

Map<String, dynamic> circle(
  String? iata,
  String name,
  double lng,
  double lat,
) =>
    {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [lng - 0.1, lat],
            [lng, lat + 0.1],
            [lng + 0.1, lat],
            [lng, lat - 0.1],
            [lng - 0.1, lat],
          ],
        ],
      },
      'properties': {'airport': name, 'iata': iata},
    };

void main() {
  test('one point per airport circle, at its center', () {
    final points = AirportPoint.fromBoundaries({
      'features': [
        circle('MNL', 'Ninoy Aquino International Airport', 121.02, 14.51),
        circle('BAG', 'Loakan Airport', 120.62, 16.38),
      ],
    });
    expect(points.map((p) => p.iata), ['MNL', 'BAG']);
    expect(points.first.longitude, closeTo(121.02, 1e-9));
    expect(points.first.latitude, closeTo(14.51, 1e-9));
  });

  test('skips circles without a code or a ring', () {
    final points = AirportPoint.fromBoundaries({
      'features': [
        circle(null, 'No Code', 0, 0),
        {
          'geometry': {
            'type': 'Point',
            'coordinates': [0, 0],
          },
          'properties': {'iata': 'PT'},
        },
      ],
    });
    expect(points, isEmpty);
    expect(AirportPoint.fromBoundaries(null), isEmpty);
  });

  test('quiet collection leaves out airports with echoes', () {
    final all = AirportPoint.fromBoundaries({
      'features': [
        circle('MNL', 'Ninoy Aquino International Airport', 121.02, 14.51),
        circle('BAG', 'Loakan Airport', 120.62, 16.38),
      ],
    });
    final fc = AirportPoint.quietCollection(all, const [
      AirportEchoCount(
        airportIata: 'MNL',
        count: 12,
        latitude: 14.51,
        longitude: 121.02,
      ),
    ]);
    final features = (fc['features'] as List).cast<Map<String, dynamic>>();
    expect(features, hasLength(1));
    expect((features.single['properties'] as Map)['name'], 'LOAKAN');
  });

  test('shortName drops "(International) Airport"', () {
    expect(
      AirportPoint.shortName('Ninoy Aquino International Airport'),
      'NINOY AQUINO',
    );
    expect(AirportPoint.shortName('Clark Airport'), 'CLARK');
  });
}
