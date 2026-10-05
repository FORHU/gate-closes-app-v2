import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_view_bounds.dart';

void main() {
  test('leaves an ordinary view alone', () {
    final v = MapViewBounds.normalize(
      west: 116,
      south: 4,
      east: 127,
      north: 21,
    );
    expect([v.west, v.south, v.east, v.north], [116, 4, 127, 21]);
  });

  test('wraps an unwrapped antimeridian crossing to west > east', () {
    // Manila to Hawaii, as Mapbox reports it: east past 180.
    final v = MapViewBounds.normalize(
      west: 110,
      south: -10,
      east: 205,
      north: 40,
    );
    expect(v.west, 110);
    expect(v.east, -155);
    expect(v.west > v.east, isTrue);
  });

  test('wraps a west edge below -180', () {
    final v = MapViewBounds.normalize(
      west: -200,
      south: 0,
      east: -150,
      north: 10,
    );
    expect(v.west, 160);
    expect(v.east, -150);
  });

  test('a view 360° or wider is the whole world', () {
    final v = MapViewBounds.normalize(
      west: -250,
      south: -95,
      east: 300,
      north: 95,
    );
    expect([v.west, v.south, v.east, v.north], [-180, -90, 180, 90]);
  });

  test('swaps edges Mapbox reports flipped across the antimeridian', () {
    // Seen on a Xiaomi (globe): a Pacific view came back as sw = -122.1,
    // ne = 114.4. The center over the Pacific is outside that range, so the
    // real view is 114.4 -> -122.1 across the antimeridian.
    final v = MapViewBounds.normalize(
      west: -122.1,
      south: -35.7,
      east: 114.4,
      north: 8.4,
      centerLng: 175,
    );
    expect(v.west, 114.4);
    expect(v.east, -122.1);
  });

  test('keeps a wide view that contains the center', () {
    final v = MapViewBounds.normalize(
      west: -100,
      south: -60,
      east: 100,
      north: 60,
      centerLng: 10,
    );
    expect([v.west, v.east], [-100, 100]);
  });

  test('keeps a crossing view that contains the center', () {
    final v = MapViewBounds.normalize(
      west: 110,
      south: -10,
      east: 205,
      north: 40,
      centerLng: -170,
    );
    expect([v.west, v.east], [110, -155]);
  });

  test('wraps an unwrapped center before checking it', () {
    final v = MapViewBounds.normalize(
      west: -150,
      south: 0,
      east: 120,
      north: 10,
      centerLng: 540, // 180
    );
    expect([v.west, v.east], [120, -150]);
  });

  test('keeps the exact edges of the world', () {
    final v = MapViewBounds.normalize(
      west: -180,
      south: -85,
      east: 180,
      north: 85,
    );
    expect([v.west, v.east], [-180, 180]);
  });
}
