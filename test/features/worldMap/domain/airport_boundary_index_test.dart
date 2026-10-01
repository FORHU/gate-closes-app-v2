import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_boundary_index.dart';

Map<String, dynamic> square(String id, double lng, double lat) => {
      'type': 'Feature',
      'id': id,
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [lng - 0.02, lat - 0.02],
            [lng + 0.02, lat - 0.02],
            [lng + 0.02, lat + 0.02],
            [lng - 0.02, lat + 0.02],
            [lng - 0.02, lat - 0.02],
          ],
        ],
      },
      'properties': {'airport': id},
    };

List<String> ids(Map<String, dynamic> fc) =>
    [for (final f in fc['features'] as List) (f as Map)['id'] as String];

void main() {
  final index = AirportBoundaryIndex.fromGeoJson({
    'type': 'FeatureCollection',
    'features': [
      square('MNL', 121.02, 14.51),
      square('CEB', 123.98, 10.31),
      square('SUV', 178.56, -18.04), // Fiji, east of the antimeridian
      square('TVU', -179.87, -16.69), // Taveuni, west of it
      {'type': 'Feature', 'geometry': null}, // skipped
    ],
  });

  test('indexes only features with a polygon', () {
    expect(index.length, 4);
  });

  test('shows nothing when zoomed out past minZoom', () {
    final fc = index.visible(
      west: -180,
      south: -85,
      east: 180,
      north: 85,
      zoom: AirportBoundaryIndex.minZoom - 0.1,
    );
    expect(fc['features'], isEmpty);
  });

  test('returns only the airports overlapping the view', () {
    final fc = index.visible(
      west: 120.5,
      south: 14,
      east: 121.5,
      north: 15,
      zoom: 11,
    );
    expect(ids(fc), ['MNL']);
    expect(fc['type'], 'FeatureCollection');
  });

  test('handles a view crossing the antimeridian', () {
    final fc = index.visible(
      west: 178,
      south: -20,
      east: -179,
      north: -15,
      zoom: 8,
    );
    expect(ids(fc), unorderedEquals(['SUV', 'TVU']));
  });

  test('caps the number of features per update', () {
    final many = AirportBoundaryIndex.fromGeoJson({
      'features': [
        for (var i = 0; i < 500; i++) square('A$i', 121 + i * 0.001, 14.5),
      ],
    });
    final fc = many.visible(
      west: 120,
      south: 14,
      east: 122,
      north: 15,
      zoom: 9,
    );
    expect(fc['features'], hasLength(AirportBoundaryIndex.maxFeatures));
  });
}
