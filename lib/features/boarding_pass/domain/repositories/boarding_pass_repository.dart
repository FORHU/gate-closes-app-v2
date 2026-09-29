import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/boarding_pass/domain/entities/boarding_pass_entity.dart';
import 'package:fpdart/fpdart.dart';

abstract class BoardingPassRepository {
  /// Ingests a scanned or manually entered boarding pass into the backend.
  Future<Either<Failure, String>> registerBoardingPass({
    required BoardingPassEntity boardingPass,
    required DateTime departureDateTime,
    required DateTime returnDateTime,
    DateTime? arrivalDateTime,
  });

  /// Fetches active boarding pass/flight ticket for the current user.
  Future<Either<Failure, BoardingPassEntity?>> getActiveBoardingPass();
}
