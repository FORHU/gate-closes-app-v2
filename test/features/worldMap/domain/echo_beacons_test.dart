import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_radar.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_beacons.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';

TerminalEchoMapNodeEntity echo(
  String id, {
  double lat = 14.508,
  double lng = 121.019,
  EchoNodeKind kind = EchoNodeKind.terminalEcho,
}) =>
    TerminalEchoMapNodeEntity(
      id: id,
      senderId: '',
      nodeKind: kind,
      latitude: lat,
      longitude: lng,
    );

double distance(EchoBeacon a, EchoBeacon b) =>
    EchoBeacons.distanceMeters(a.lng, a.lat, b.lng, b.lat);

void main() {
  group('place', () {
    test('an echo alone on its spot stays put', () {
      final placed = EchoBeacons.place([echo('a')]);
      expect(placed.single.lng, 121.019);
      expect(placed.single.lat, 14.508);
    });

    test('echoes sharing a spot stand apart, as a small crowd', () {
      final placed =
          EchoBeacons.place([for (var i = 0; i < 12; i++) echo('e$i')]);
      expect(placed, hasLength(12));
      for (var i = 0; i < placed.length; i++) {
        for (var j = i + 1; j < placed.length; j++) {
          expect(distance(placed[i], placed[j]), greaterThan(1.5));
        }
      }
      // Still inside the ~110 m rounding cell.
      final middle = placed.firstWhere((b) => b.node.id == 'e0');
      for (final b in placed) {
        expect(distance(b, middle), lessThan(20));
      }
    });

    test('the arrangement does not depend on the order the API sent', () {
      final ids = ['c', 'a', 'b'];
      final one = EchoBeacons.place([for (final id in ids) echo(id)]);
      final two = EchoBeacons.place([for (final id in ids.reversed) echo(id)]);
      final where = {for (final b in one) b.node.id: (b.lng, b.lat)};
      for (final b in two) {
        expect((b.lng, b.lat), where[b.node.id]);
      }
    });
  });

  test('points sit at the drawn positions with pin properties', () {
    final placed = EchoBeacons.place([echo('a'), echo('b')]);
    final fc = EchoBeacons.points(placed);
    final features = (fc['features'] as List).cast<Map<String, dynamic>>();
    for (final (i, f) in features.indexed) {
      expect((f['geometry'] as Map)['coordinates'], [
        placed[i].lng,
        placed[i].lat,
      ]);
      expect((f['properties'] as Map)['id'], placed[i].node.id);
    }
  });

  group('radar bearing', () {
    test('is clockwise from north, as the sweep heading', () {
      double b(double lng, double lat) =>
          EchoBeacons.bearingDeg(lng, lat, fromLng: 121, fromLat: 14.5);
      expect(b(121, 14.51), closeTo(0, 0.01));
      expect(b(121.01, 14.5), closeTo(90, 0.01));
      expect(b(121, 14.49), closeTo(180, 0.01));
      expect(b(120.99, 14.5), closeTo(270, 0.01));
    });

    test('is set on echoes inside a radar disc only', () {
      const disc = RadarDisc(lng: 121.019, lat: 14.5, radiusKm: 2);
      final placed = EchoBeacons.place([
        echo('in'),
        echo('out', lat: 14.6),
      ]);
      final fc = EchoBeacons.points(placed, radar: const [disc]);
      final props = {
        for (final f in (fc['features'] as List).cast<Map<String, dynamic>>())
          (f['properties'] as Map)['id']: f['properties'] as Map,
      };
      expect(props['in']!['radarBearing'] as double, closeTo(0, 0.01));
      expect(props['out']!.containsKey('radarBearing'), isFalse);
    });
  });

  test('metersPerPoint halves with each zoom step', () {
    final z16 = EchoBeacons.metersPerPoint(16, 0);
    expect(z16, closeTo(1.194, 0.001));
    expect(EchoBeacons.metersPerPoint(17, 0), closeTo(z16 / 2, 1e-9));
    expect(EchoBeacons.metersPerPoint(16, 60), closeTo(z16 / 2, 1e-9));
  });

  test('near finds every echo under a finger, nearest first', () {
    final placed = EchoBeacons.place([
      echo('a'),
      echo('b'),
      echo('far', lat: 14.52),
    ]);
    final hits =
        EchoBeacons.near(placed, lng: 121.019, lat: 14.508, meters: 20);
    expect(hits.map((e) => e.id), ['a', 'b']);
  });

  group('hotspot', () {
    test('is the busiest spot near the echo closest to the center', () {
      final spot = EchoBeacons.hotspot(
        [
          echo('a'),
          echo('b', lat: 14.509),
          echo('c', lat: 14.509),
          // A busier spot at another airport, far from the view center.
          for (var i = 0; i < 5; i++) echo('x$i', lat: 10.3, lng: 123.98),
        ],
        centerLng: 121.019,
        centerLat: 14.508,
      );
      expect(spot!.lat, 14.509);
      expect(spot.count, 2);
    });

    test('is null without echoes', () {
      expect(
        EchoBeacons.hotspot([], centerLng: 0, centerLat: 0),
        isNull,
      );
    });
  });
}
