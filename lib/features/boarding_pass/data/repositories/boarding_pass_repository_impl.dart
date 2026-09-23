import 'package:flutter_template/core/constants/api_endpoints.dart';
import 'package:flutter_template/core/errors/exceptions.dart';
import 'package:flutter_template/core/errors/failure.dart';
import 'package:flutter_template/core/services/api_service.dart';
import 'package:flutter_template/features/boarding_pass/domain/entities/boarding_pass_entity.dart';
import 'package:flutter_template/features/boarding_pass/domain/repositories/boarding_pass_repository.dart';
import 'package:fpdart/fpdart.dart';

class BoardingPassRepositoryImpl implements BoardingPassRepository {
  const BoardingPassRepositoryImpl(this._api);

  final ApiService _api;

  @override
  Future<Either<Failure, String>> registerBoardingPass({
    required BoardingPassEntity boardingPass,
    required DateTime departureDateTime,
    required DateTime returnDateTime,
    DateTime? arrivalDateTime,
  }) async {
    try {
      final payload = <String, dynamic>{
        'flightNumber':
            '${boardingPass.airline} ${boardingPass.flightNumber}'.trim(),
        'fromAirport': boardingPass.fromAirport,
        'toAirport': boardingPass.toAirport,
        'departureDateTime': departureDateTime.toIso8601String(),
        'returnDateTime': returnDateTime.toIso8601String(),
      };

      if (arrivalDateTime != null) {
        payload['arrivalDateTime'] = arrivalDateTime.toIso8601String();
      }

      final response = await _api.post(ApiEndpoints.flightTicket, payload);
      final message =
          (response as Map)['message']?.toString() ?? 'Ticket registered.';
      return Right(message);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BoardingPassEntity?>> getActiveBoardingPass() async {
    try {
      final response = await _api.get(ApiEndpoints.flightTicket);
      if (response == null) return const Right(null);

      final rawData = (response as Map)['data'];
      if (rawData is! Map) return const Right(null);

      final map = rawData.cast<String, dynamic>();
      final flightNum = (map['flightNumber'] ?? '').toString();
      final parts = flightNum.split(' ');
      final airline = parts.isNotEmpty ? parts.first : '';
      final number = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final entity = BoardingPassEntity(
        passengerName: (map['passengerName'] ?? '').toString(),
        pnr: (map['pnr'] ?? '').toString(),
        fromAirport: (map['fromAirport'] ?? '').toString(),
        toAirport: (map['toAirport'] ?? '').toString(),
        airline: airline,
        flightNumber: number,
        date: (map['departureDateTime'] ?? '').toString().split('T').first,
        seat: map['seat']?.toString(),
      );

      return Right(entity);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
