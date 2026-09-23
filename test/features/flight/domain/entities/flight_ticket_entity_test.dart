import 'package:flutter_template/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightTicketEntity Lifecycle & Dwell Time Calculation', () {
    final departureTime = DateTime(2026, 9, 23, 14); // 14:00
    final arrivalTime = DateTime(2026, 9, 23, 20); // 20:00
    final returnTime = DateTime(2026, 9, 30, 10);

    final ticket = FlightTicketEntity(
      id: 'ticket1',
      userId: 'user1',
      flightNumber: 'SQ 322',
      fromAirport: 'SIN',
      toAirport: 'LHR',
      departureDateTime: departureTime,
      returnDateTime: returnTime,
      arrivalDateTime: arrivalTime,
    );

    test('status is upcoming when current time is > 6 hours before departure',
        () {
      final now = DateTime(2026, 9, 23, 7); // 7 hours before
      expect(ticket.getStatus(now), FlightStatus.upcoming);
      expect(ticket.isInsideDwellWindow(now), isFalse);
    });

    test(
        'status is active when current time is within 6 hours before departure',
        () {
      final now = DateTime(2026, 9, 23, 11, 30); // 2.5 hours before
      expect(ticket.getStatus(now), FlightStatus.active);
      expect(ticket.isInsideDwellWindow(now), isTrue);
      expect(
        ticket.getRemainingDwellTime(now),
        const Duration(hours: 2, minutes: 30),
      );
    });

    test('status is departed during flight before arrival', () {
      final now = DateTime(2026, 9, 23, 16); // 2 hours after departure
      expect(ticket.getStatus(now), FlightStatus.departed);
      expect(ticket.isInsideDwellWindow(now), isFalse);
      expect(ticket.getRemainingDwellTime(now), Duration.zero);
    });

    test('status is completed after arrival', () {
      final now = DateTime(2026, 9, 23, 22); // after arrival
      expect(ticket.getStatus(now), FlightStatus.completed);
      expect(ticket.isInsideDwellWindow(now), isFalse);
    });
  });
}
