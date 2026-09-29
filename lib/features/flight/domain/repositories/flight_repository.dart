import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:fpdart/fpdart.dart';

abstract class FlightRepository {
  /// Loads current user's active flight ticket.
  Future<Either<Failure, FlightTicketEntity?>> getActiveFlightTicket();

  /// Creates a new flight ticket for the current user.
  Future<Either<Failure, String>> createFlightTicket({
    required String flightNumber,
    required String fromAirport,
    required String toAirport,
    required DateTime departureDateTime,
    required DateTime returnDateTime,
    DateTime? arrivalDateTime,
  });

  /// Updates an existing flight ticket for the current user.
  Future<Either<Failure, String>> updateFlightTicket({
    String? flightNumber,
    String? fromAirport,
    String? toAirport,
    DateTime? departureDateTime,
    DateTime? returnDateTime,
    DateTime? arrivalDateTime,
  });

  /// Deletes or dismisses the user's flight ticket.
  Future<Either<Failure, void>> deleteFlightTicket();
}
