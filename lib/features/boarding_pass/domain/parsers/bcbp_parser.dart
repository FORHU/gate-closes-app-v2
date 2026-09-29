import 'package:gate_closes/features/boarding_pass/domain/entities/boarding_pass_entity.dart';

/// Pure Dart parser for IATA Resolution 791 BCBP (Bar Coded Boarding Pass)
/// data. Independent of Flutter UI and device hardware.
class BcbpParser {
  const BcbpParser._();

  /// Parses raw barcode text string into a [BoardingPassEntity].
  /// Returns null if format is invalid or missing required IATA fields.
  static BoardingPassEntity? parse(String rawData) {
    try {
      final trimmed = rawData.trim();
      // IATA BCBP format must start with 'M' followed by legs (e.g. 'M1')
      if (!trimmed.startsWith('M') || trimmed.length < 47) {
        return null;
      }

      // Format Version & Number of Legs (M1 = 1 leg)
      // Passenger Name (20 chars starting from index 2)
      final rawName = trimmed.substring(2, 22).trim();
      final passengerName = rawName.replaceAll('/', ' ');

      // Electronic Ticket Indicator (index 22)
      // PNR / Booking reference (index 23, 7 chars)
      final pnr = trimmed.substring(23, 30).trim();

      // Origin Airport IATA (index 30, 3 chars)
      final fromAirport = trimmed.substring(30, 33).trim().toUpperCase();

      // Destination Airport IATA (index 33, 3 chars)
      final toAirport = trimmed.substring(33, 36).trim().toUpperCase();

      // Operating Carrier / Airline (index 36, 3 chars)
      final airline = trimmed.substring(36, 39).trim().toUpperCase();

      // Flight Number (index 39, 5 chars)
      final flightNumber = trimmed.substring(39, 44).trim();

      // Date of Flight (Julian Day, index 44, 3 chars)
      final julianDayStr = trimmed.substring(44, 47).trim();
      final julianDay = int.tryParse(julianDayStr);
      if (julianDay == null || julianDay < 1 || julianDay > 366) {
        return null;
      }

      final currentYear = DateTime.now().year;
      // Jan 1st of current year + (julianDay - 1) days
      final flightDate =
          DateTime(currentYear).add(Duration(days: julianDay - 1));
      final monthStr = flightDate.month.toString().padLeft(2, '0');
      final dayStr = flightDate.day.toString().padLeft(2, '0');
      final dateFormatted = '${flightDate.year}-$monthStr-$dayStr';

      // Seat Number (index 48, 4 chars if present)
      String? seat;
      if (trimmed.length >= 52) {
        final seatCandidate = trimmed.substring(48, 52).trim();
        if (seatCandidate.isNotEmpty) {
          seat = seatCandidate;
        }
      }

      if (fromAirport.isEmpty || toAirport.isEmpty || airline.isEmpty) {
        return null;
      }

      return BoardingPassEntity(
        passengerName: passengerName,
        pnr: pnr,
        fromAirport: fromAirport,
        toAirport: toAirport,
        airline: airline,
        flightNumber: flightNumber,
        date: dateFormatted,
        seat: seat,
      );
    } on Object {
      return null;
    }
  }
}
