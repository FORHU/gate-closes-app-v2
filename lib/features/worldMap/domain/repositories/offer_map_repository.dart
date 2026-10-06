import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_offer.dart';

/// Offers (ads, vouchers...) at airports, for the map. Owned by `worldMap`
/// like `EchoMapRepository`, so the map needs no other feature.
abstract class OfferMapRepository {
  /// One airport's pins and card (`GET /offers?airport=MNL`).
  Future<Either<Failure, AirportOffers>> getAirportOffers(String airportIata);

  /// Records that a traveler saw ([OfferEvent.view]) or opened
  /// ([OfferEvent.click]) an offer. Best effort: failures are ignored.
  Future<void> track(String offerId, OfferEvent event, {String? airportIata});

  /// Claims a voucher-like offer; a [ServerFailure] carries the API's reason
  /// (run out, already claimed, ended).
  Future<Either<Failure, OfferReward>> claim(
    String offerId, {
    String? airportIata,
  });
}

enum OfferEvent { view, click }
