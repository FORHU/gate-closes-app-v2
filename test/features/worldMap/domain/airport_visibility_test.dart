import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_visibility.dart';

void main() {
  group('facesCamera', () {
    bool faces(double lat, double lng) => AirportVisibility.facesCamera(
          lat: lat,
          lng: lng,
          centerLat: 0,
          centerLng: 0,
        );

    test('the near side of the globe faces the camera', () {
      expect(faces(0, 0), isTrue);
      expect(faces(10, 60), isTrue);
    });

    test('the rim and the far side do not', () {
      expect(faces(0, 90), isFalse);
      expect(faces(0, 180), isFalse);
    });
  });

  group('viewAngleDeg', () {
    double angle(double zoom) =>
        AirportVisibility.viewAngleDeg(zoom, halfDiagonal: 1100);

    test('is the globe rim when zoomed out', () {
      expect(angle(2.8), 75);
    });

    test('shrinks as the camera zooms in', () {
      expect(angle(7), lessThan(20));
      expect(angle(10), lessThan(angle(7)));
    });

    test('keeps an airport round the globe off a zoomed-in view', () {
      // JFK seen from over Luzon at zoom 7.
      expect(
        AirportVisibility.facesCamera(
          lat: 40.64,
          lng: -73.79,
          centerLat: 16.4,
          centerLng: 120.6,
          maxAngleDeg: angle(7),
        ),
        isFalse,
      );
      // Clark, 80 km away, still gets one.
      expect(
        AirportVisibility.facesCamera(
          lat: 15.19,
          lng: 120.56,
          centerLat: 16.4,
          centerLng: 120.6,
          maxAngleDeg: angle(7),
        ),
        isTrue,
      );
    });
  });
}
