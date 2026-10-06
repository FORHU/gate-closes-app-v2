import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5, 12);

  test('parses an API feature', () {
    final c = AirportEchoCount.fromGeoJsonFeature({
      'id': 'MNL',
      'geometry': {
        'type': 'Point',
        'coordinates': [121.019208, 14.511205],
      },
      'properties': {
        'airportIata': 'MNL',
        'airportName': 'Ninoy Aquino International Airport',
        'count': 12,
        'latestAt': '2026-10-05T11:50:00.000Z',
      },
    })!;
    expect(c.airportIata, 'MNL');
    expect(c.airportName, 'Ninoy Aquino International Airport');
    expect(c.count, 12);
    expect(c.longitude, 121.019208);
    expect(c.latitude, 14.511205);
    expect(c.latestAt, DateTime.utc(2026, 10, 5, 11, 50));
  });

  test('no airport code or no point: null', () {
    expect(
      AirportEchoCount.fromGeoJsonFeature({
        'geometry': {
          'coordinates': [1, 2],
        },
        'properties': {'count': 1},
      }),
      isNull,
    );
    expect(
      AirportEchoCount.fromGeoJsonFeature({
        'id': 'MNL',
        'geometry': null,
        'properties': {'airportIata': 'MNL'},
      }),
      isNull,
    );
  });

  test('heat weight grows with the count, on a log scale, capped', () {
    AirportEchoCount n(int count) => AirportEchoCount(
          airportIata: 'X',
          count: count,
          latitude: 0,
          longitude: 0,
        );
    expect(n(1).heatWeight, closeTo(0.97, 0.01));
    expect(n(12).heatWeight, closeTo(1.44, 0.01));
    expect(n(12).heatWeight, greaterThan(n(1).heatWeight));
    expect(n(1000000).heatWeight, 2);
    expect(n(1).cloudScale, closeTo(1.21, 0.01));
    expect(n(12).cloudScale, closeTo(1.77, 0.01));
    expect(n(1000000).cloudScale, 2.4);
  });

  test('collection: heat weight and heatmap scores', () {
    final fc = AirportEchoCount.collection(
      [
        AirportEchoCount(
          airportIata: 'MNL',
          count: 12,
          latitude: 14.5,
          longitude: 121,
          latestAt: now.subtract(const Duration(minutes: 5)),
        ),
        const AirportEchoCount(
          airportIata: 'BAG',
          count: 1,
          latitude: 16.4,
          longitude: 120.6,
        ),
      ],
      now: now,
    );
    final features = fc['features'] as List;
    final mnl = (features[0] as Map)['properties'] as Map;
    final bag = (features[1] as Map)['properties'] as Map;
    expect((features[0] as Map)['geometry'], {
      'type': 'Point',
      'coordinates': [121.0, 14.5],
    });
    expect(mnl['heatWeight'], closeTo(1.44, 0.01));
    expect(mnl['activityScore'], 2);
    expect(mnl['freshnessScore'], 2);
    expect(bag['activityScore'], 0);
    expect(bag['freshnessScore'], 1);
  });

  test('collection round-trips through the offline cache', () {
    const c = AirportEchoCount(
      airportIata: 'MNL',
      airportName: 'NAIA',
      count: 3,
      latitude: 14.5,
      longitude: 121,
    );
    final feature = (AirportEchoCount.collection([c])['features'] as List)
        .single as Map<String, dynamic>;
    expect(AirportEchoCount.fromGeoJsonFeature(feature), c);
  });
}
