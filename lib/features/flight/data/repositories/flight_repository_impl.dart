import 'package:flutter_template/core/constants/api_endpoints.dart';
import 'package:flutter_template/core/errors/exceptions.dart';
import 'package:flutter_template/core/errors/failure.dart';
import 'package:flutter_template/core/services/api_service.dart';
import 'package:flutter_template/features/flight/data/models/flight_ticket_model.dart';
import 'package:flutter_template/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:flutter_template/features/flight/domain/repositories/flight_repository.dart';
import 'package:fpdart/fpdart.dart';

class FlightRepositoryImpl implements FlightRepository {
  const FlightRepositoryImpl(this._api);

  final ApiService _api;

  @override
  Future<Either<Failure, FlightTicketEntity?>> getActiveFlightTicket() async {
    try {
      final response = await _api.get(ApiEndpoints.flightTicket);
      if (response == null) return const Right(null);

      final rawData = (response as Map)['data'];
      if (rawData == null || rawData is! Map) return const Right(null);

      final model =
          FlightTicketModel.fromJson(response.cast<String, dynamic>());
      return Right(model);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteFlightTicket() async {
    try {
      await _api.delete(ApiEndpoints.flightTicket);
      return const Right(null);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
