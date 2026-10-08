import 'package:equatable/equatable.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_radar.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_beacons.dart';

/// Something promoted at an airport (an ad, a voucher...), as the map shows
/// it (`GET /offers?airport=MNL`). The API places pins at a random spot
/// inside the airport, fixed per traveler for the day; the card has no spot.
class MapOffer extends Equatable {
  const MapOffer({
    required this.id,
    required this.airportIata,
    required this.kind,
    required this.title,
    this.body,
    this.imageUrl,
    this.ctaLabel,
    this.ctaUrl,
    this.details = const {},
    this.endsAt,
    this.claimable = false,
    this.longitude,
    this.latitude,
  });

  /// From the API's public offer (`card`, or a pin's `properties`).
  /// Null without an id or title.
  static MapOffer? fromJson(
    Map<String, dynamic> json, {
    required String airportIata,
    double? longitude,
    double? latitude,
  }) {
    final id = json['id']?.toString();
    final title = json['title']?.toString();
    if (id == null || id.isEmpty || title == null || title.isEmpty) {
      return null;
    }
    String? text(String key) {
      final value = json[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    final details = json['data'];
    final endsAt = json['endsAt'];
    return MapOffer(
      id: id,
      airportIata: airportIata,
      kind: text('kind') ?? 'ad',
      title: title,
      body: text('body'),
      imageUrl: text('imageUrl'),
      ctaLabel: text('ctaLabel'),
      ctaUrl: text('ctaUrl'),
      details: details is Map ? details.cast<String, dynamic>() : const {},
      endsAt: endsAt == null ? null : DateTime.tryParse('$endsAt'),
      claimable: json['claimable'] == true,
      longitude: longitude,
      latitude: latitude,
    );
  }

  /// A pin feature: the offer in `properties`, its spot in `geometry`.
  static MapOffer? fromPinFeature(
    Map<String, dynamic> feature, {
    required String airportIata,
  }) {
    final coordinates = (feature['geometry'] as Map?)?['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    final lng = coordinates[0];
    final lat = coordinates[1];
    if (lng is! num || lat is! num) return null;
    final properties =
        (feature['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
    return fromJson(
      properties,
      airportIata: airportIata,
      longitude: lng.toDouble(),
      latitude: lat.toDouble(),
    );
  }

  final String id;
  final String airportIata;

  /// Free text set by the admin: "ad", "voucher", or a new kind.
  final String kind;
  final String title;
  final String? body;
  final String? imageUrl;
  final String? ctaLabel;
  final String? ctaUrl;

  /// Per-kind fields shown to everyone, e.g. `{discount: "20%"}`.
  final Map<String, dynamic> details;
  final DateTime? endsAt;

  /// Has a reward (e.g. a voucher code) revealed only by claiming.
  final bool claimable;

  /// Set on pins only.
  final double? longitude;
  final double? latitude;

  bool get isPin => longitude != null && latitude != null;

  @override
  List<Object?> get props => [
        id,
        airportIata,
        kind,
        title,
        body,
        imageUrl,
        ctaLabel,
        ctaUrl,
        details,
        endsAt,
        claimable,
        longitude,
        latitude,
      ];
}

/// What one airport offers: its pins and at most one card.
class AirportOffers extends Equatable {
  const AirportOffers({this.card, this.pins = const []});

  /// `GET /offers?airport=…` → `{card, pins: FeatureCollection}`.
  factory AirportOffers.fromJson(
    Map<String, dynamic> json, {
    required String airportIata,
  }) {
    final card = json['card'];
    final features = (json['pins'] as Map?)?['features'];
    return AirportOffers(
      card: card is Map
          ? MapOffer.fromJson(
              card.cast<String, dynamic>(),
              airportIata: airportIata,
            )
          : null,
      pins: features is List
          ? features
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (f) => MapOffer.fromPinFeature(
                  f.cast<String, dynamic>(),
                  airportIata: airportIata,
                ),
              )
              .whereType<MapOffer>()
              .toList()
          : const [],
    );
  }

  static const empty = AirportOffers();

  final MapOffer? card;
  final List<MapOffer> pins;

  @override
  List<Object?> get props => [card, pins];
}

/// What claiming gave: the offer's reward, e.g. `{code: "GATE20"}`.
class OfferReward extends Equatable {
  const OfferReward(this.fields);

  final Map<String, dynamic> fields;

  /// The usual voucher field, when there is one.
  String? get code => fields['code']?.toString();

  @override
  List<Object?> get props => [fields];
}

/// The three families the map shows offers in. `kind` is free text set by
/// the admin; vouchers and gifts are recognised by name, everything else
/// (ads, lounge passes, new kinds) counts as an ad.
enum OfferGroup {
  voucher('🎟', 'Vouchers'),
  gift('🎁', 'Gifts'),
  ad('📢', 'Offers');

  const OfferGroup(this.emoji, this.label);

  final String emoji;
  final String label;

  static OfferGroup of(String kind) {
    final k = kind.toLowerCase();
    if (k.contains('voucher') || k.contains('coupon')) return voucher;
    if (k.contains('gift')) return gift;
    return ad;
  }
}

/// GeoJSON for the map's offer pin layer, built at the edge like
/// `EchoMapFeatures`: only what the layers and taps need (the page looks
/// the offer up by `id`), its `group` for the glow color, and inside a
/// `radar` disc its `radarBearing`, so the sweep detects offers as it does
/// echoes. Offers without a spot are left out.
abstract final class OfferMapFeatures {
  static Map<String, dynamic> collection(
    List<MapOffer> offers, {
    List<RadarDisc> radar = const [],
  }) =>
      {
        'type': 'FeatureCollection',
        'features': [
          for (final offer in offers)
            if (offer.isPin)
              {
                'type': 'Feature',
                'id': offer.id,
                'geometry': {
                  'type': 'Point',
                  'coordinates': [offer.longitude, offer.latitude],
                },
                'properties': {
                  'id': offer.id,
                  'group': OfferGroup.of(offer.kind).name,
                  if (EchoBeacons.radarBearing(
                    offer.longitude!,
                    offer.latitude!,
                    radar,
                  )
                      case final bearing?)
                    'radarBearing': bearing,
                },
              },
        ],
      };
}
