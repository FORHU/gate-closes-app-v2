import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_pin_plan.dart';

AirportEchoCount _airport(String iata, double lng, double lat, [int n = 1]) =>
    AirportEchoCount(
      airportIata: iata,
      count: n,
      latitude: lat,
      longitude: lng,
    );

void main() {
  final counts = [
    _airport('MNL', 121.0192, 14.5112, 12),
    _airport('CRK', 120.5603, 15.1859, 3),
    _airport('BAG', 120.6178, 16.3767),
    _airport('SIN', 103.9915, 1.3644),
    _airport('NAN', 177.4433, -17.7554), // Fiji
    _airport('HNL', -157.9224, 21.3187), // Honolulu
    _airport('EMPTY', 121.05, 14.55, 0),
  ];

  AirportPinPlan plan({
    required double west,
    required double south,
    required double east,
    required double north,
    double zoom = 12,
    double? centerLng,
    double? centerLat,
  }) =>
      AirportPinPlan.forView(
        counts: counts,
        west: west,
        south: south,
        east: east,
        north: north,
        zoom: zoom,
        centerLng: centerLng ?? (west + east) / 2,
        centerLat: centerLat ?? (south + north) / 2,
      );

  test('below the pins zoom: counts, nothing to load', () {
    final p = plan(west: 116, south: 4, east: 127, north: 21, zoom: 5);
    expect(p.mode, MapPinMode.counts);
    expect(p.airports, isEmpty);
  });

  test('zoomed in on NAIA: only MNL, never airports without echoes', () {
    final p = plan(west: 120.97, south: 14.45, east: 121.06, north: 14.58);
    expect(p.mode, MapPinMode.pins);
    expect(p.airports, ['MNL']);
  });

  test('an airport just outside the view still loads (margin)', () {
    // The view ends 0.3° west of NAIA.
    final p = plan(west: 120.2, south: 14.3, east: 120.7, north: 14.7);
    expect(p.airports, contains('MNL'));
  });

  test('nearest the view center first', () {
    final p = plan(
      west: 119,
      south: 13,
      east: 123,
      north: 17,
      zoom: AirportPinPlan.pinsMinZoom,
      centerLng: 120.6,
      centerLat: 16.3,
    );
    expect(p.airports, ['BAG', 'CRK', 'MNL']);
  });

  test('at most maxAirports', () {
    final many = [
      for (var i = 0; i < 20; i++) _airport('A$i', 121 + i * 0.01, 14.5),
    ];
    final p = AirportPinPlan.forView(
      counts: many,
      west: 120,
      south: 14,
      east: 123,
      north: 15,
      zoom: AirportPinPlan.pinsMinZoom,
      centerLng: 121,
      centerLat: 14.5,
    );
    expect(p.airports, hasLength(AirportPinPlan.maxAirports));
    expect(p.airports.first, 'A0');
  });

  test('a view across the antimeridian finds airports on both sides', () {
    // Flipped edges, as normalized by MapViewBounds: west > east.
    final p = plan(
      west: 170,
      south: -30,
      east: -150,
      north: 30,
      zoom: AirportPinPlan.pinsMinZoom,
      centerLng: -170,
      centerLat: 0,
    );
    expect(p.airports, unorderedEquals(['NAN', 'HNL']));
  });

  test('a whole-world view at pins zoom keeps every longitude', () {
    final p = plan(
      west: -180,
      south: -5,
      east: 180,
      north: 20,
      zoom: AirportPinPlan.pinsMinZoom,
    );
    expect(p.airports, contains('SIN'));
    expect(p.airports, contains('MNL'));
  });
}
