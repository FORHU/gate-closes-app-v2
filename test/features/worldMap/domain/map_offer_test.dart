import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_radar.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_offer.dart';

void main() {
  // GET /offers?airport=MNL, as gate-closes-api answers it.
  final response = <String, dynamic>{
    'card': {
      'id': 'card1',
      'kind': 'voucher',
      'title': 'Coffee 20% off',
      'body': '  ',
      'imageUrl': null,
      'ctaLabel': 'Get it',
      'ctaUrl': 'https://example.com/coffee',
      'data': {'discount': '20%'},
      'endsAt': '2026-12-31T00:00:00.000Z',
      'claimable': true,
    },
    'pins': {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [121.02, 14.5],
          },
          'properties': {'id': 'pin1', 'kind': 'ad', 'title': 'Lounge'},
        },
        // Unusable: no spot, then no title.
        {
          'geometry': {'type': 'Point', 'coordinates': <num>[]},
          'properties': {'id': 'x', 'title': 'No spot'},
        },
        {
          'geometry': {
            'type': 'Point',
            'coordinates': [121, 14],
          },
          'properties': {'id': 'y'},
        },
      ],
    },
  };

  test('parses the card and the pins, skipping unusable ones', () {
    final offers = AirportOffers.fromJson(response, airportIata: 'MNL');

    final card = offers.card!;
    expect(card.id, 'card1');
    expect(card.airportIata, 'MNL');
    expect(card.kind, 'voucher');
    expect(card.body, isNull, reason: 'blank text counts as none');
    expect(card.details, {'discount': '20%'});
    expect(card.endsAt, DateTime.utc(2026, 12, 31));
    expect(card.claimable, isTrue);
    expect(card.isPin, isFalse);

    expect(offers.pins, hasLength(1));
    final pin = offers.pins.single;
    expect(pin.id, 'pin1');
    expect(pin.isPin, isTrue);
    expect((pin.longitude, pin.latitude), (121.02, 14.5));
    expect(pin.claimable, isFalse);
  });

  test('no card and no pins is empty, not an error', () {
    final offers = AirportOffers.fromJson(
      const {'card': null},
      airportIata: 'BAG',
    );
    expect(offers, AirportOffers.empty);
  });

  test('map features carry the id and group, only for offers with a spot', () {
    final offers = AirportOffers.fromJson(response, airportIata: 'MNL');
    final collection =
        OfferMapFeatures.collection([offers.card!, ...offers.pins]);

    final features = collection['features'] as List;
    expect(features, hasLength(1));
    final feature = features.single as Map<String, dynamic>;
    final pin = offers.pins.single;
    expect(feature['properties'], {
      'id': 'pin1',
      'group': OfferGroup.of(pin.kind).name,
    });
    expect((feature['geometry'] as Map)['coordinates'], [121.02, 14.5]);
  });

  test('inside a radar disc an offer carries its bearing for the sweep', () {
    final offers = AirportOffers.fromJson(response, airportIata: 'MNL');
    final collection = OfferMapFeatures.collection(
      offers.pins,
      radar: const [RadarDisc(lng: 121.02, lat: 14.49, radiusKm: 3)],
    );
    final props = ((collection['features'] as List).single
        as Map<String, dynamic>)['properties'] as Map;
    // The pin is due north of the disc's center.
    expect(props['radarBearing'] as double, closeTo(0, 0.01));
  });

  test('a reward exposes its voucher code', () {
    expect(const OfferReward({'code': 'GATE20'}).code, 'GATE20');
    expect(const OfferReward({'pin': '1234'}).code, isNull);
  });
}
