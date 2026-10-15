import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/notifications/flight_reminder.dart';
import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';

FlightTicketEntity _ticket(DateTime departs) => FlightTicketEntity(
      id: 't1',
      userId: 'u1',
      flightNumber: 'PR501',
      fromAirport: 'mnl',
      toAirport: 'SIN',
      departureDateTime: departs,
    );

void main() {
  final departs = DateTime.utc(2026, 10, 15, 10);

  test('fires three hours before departure', () {
    final reminder = planFlightReminder(
      _ticket(departs),
      enabled: true,
      now: DateTime.utc(2026, 10, 15, 6),
    );

    expect(reminder, isNotNull);
    expect(reminder!.at, DateTime.utc(2026, 10, 15, 7));
    expect(reminder.title, 'PR501 to SIN departs in 3 hours');
    expect(reminder.body, "Flying MNL → SIN. See who's at MNL.");
  });

  test('works from a local departure time too', () {
    final reminder = planFlightReminder(
      _ticket(departs.toLocal()),
      enabled: true,
      now: DateTime.utc(2026, 10, 15, 6),
    );
    expect(reminder!.at, DateTime.utc(2026, 10, 15, 7));
  });

  test('none when reminders are off', () {
    expect(
      planFlightReminder(
        _ticket(departs),
        enabled: false,
        now: DateTime.utc(2026, 10, 15, 6),
      ),
      isNull,
    );
  });

  test('none when departure is already less than three hours away', () {
    expect(
      planFlightReminder(
        _ticket(departs),
        enabled: true,
        now: DateTime.utc(2026, 10, 15, 7, 30),
      ),
      isNull,
    );
    expect(
      planFlightReminder(
        _ticket(departs),
        enabled: true,
        now: DateTime.utc(2026, 10, 15, 7),
      ),
      isNull,
    );
  });
}
