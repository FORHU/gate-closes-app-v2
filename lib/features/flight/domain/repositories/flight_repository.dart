import 'package:flutter_template/core/errors/failure.dart';
import 'package:flutter_template/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:fpdart/fpdart.dart';

abstract class FlightRepository {
  /// Loads current user's active flight ticket.
  Future<Either<Failure, FlightTicketEntity?>> getActiveFlightTicket();

  /// Deletes or dismisses the user's flight ticket.
  Future<Either<Failure, void>> deleteFlightTicket();
}
