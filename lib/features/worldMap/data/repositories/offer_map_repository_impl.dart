import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_offer.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/offer_map_repository.dart';

class OfferMapRepositoryImpl implements OfferMapRepository {
  const OfferMapRepositoryImpl(this._api);

  final ApiService _api;

  @override
  Future<Either<Failure, AirportOffers>> getAirportOffers(
    String airportIata,
  ) =>
      _guard(() async {
        final response = await _api.get(
          ApiEndpoints.offers,
          query: {'airport': airportIata},
        );
        final data = response is Map ? response['data'] : null;
        return data is Map
            ? AirportOffers.fromJson(
                data.cast<String, dynamic>(),
                airportIata: airportIata,
              )
            : AirportOffers.empty;
      });

  @override
  Future<void> track(
    String offerId,
    OfferEvent event, {
    String? airportIata,
  }) async {
    try {
      await _api.post(ApiEndpoints.offerEvents(offerId), {
        'type': event.name,
        if (airportIata != null) 'airport': airportIata,
      });
    } on Object {
      // Stats only: never worth an error on screen.
    }
  }

  @override
  Future<Either<Failure, OfferReward>> claim(
    String offerId, {
    String? airportIata,
  }) =>
      _guard(() async {
        final response = await _api.post(ApiEndpoints.offerClaim(offerId), {
          if (airportIata != null) 'airport': airportIata,
        });
        final data = response is Map ? response['data'] : null;
        final reward = data is Map ? data['reward'] : null;
        return OfferReward(
          reward is Map ? reward.cast<String, dynamic>() : const {},
        );
      });

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
