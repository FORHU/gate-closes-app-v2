import 'package:equatable/equatable.dart';

/// Pure domain entity representing an extracted IATA Bar Coded Boarding Pass.
class BoardingPassEntity extends Equatable {
  const BoardingPassEntity({
    required this.passengerName,
    required this.pnr,
    required this.fromAirport,
    required this.toAirport,
    required this.airline,
    required this.flightNumber,
    required this.date,
    this.seat,
  });

  final String passengerName;
  final String pnr;
  final String fromAirport;
  final String toAirport;
  final String airline;
  final String flightNumber;
  final String date; // YYYY-MM-DD
  final String? seat;

  @override
  List<Object?> get props => [
        passengerName,
        pnr,
        fromAirport,
        toAirport,
        airline,
        flightNumber,
        date,
        seat,
      ];
}
