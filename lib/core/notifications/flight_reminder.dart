import 'package:equatable/equatable.dart';
import 'package:gate_closes/core/notifications/app_notification.dart';
import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';

/// How long before departure the reminder fires.
const flightReminderLead = Duration(hours: 3);

/// The app keeps one flight (the active ticket), so one reminder slot.
final int flightReminderId = notificationIdFor('flight-reminder');

/// A reminder to schedule for [ticket], or null when there should be none:
/// reminders off, or departure already less than [flightReminderLead] away.
FlightReminder? planFlightReminder(
  FlightTicketEntity ticket, {
  required bool enabled,
  required DateTime now,
}) {
  if (!enabled) return null;
  final at = ticket.departureDateTime.toUtc().subtract(flightReminderLead);
  if (!at.isAfter(now.toUtc())) return null;
  final from = ticket.fromAirport.toUpperCase();
  final to = ticket.toAirport.toUpperCase();
  return FlightReminder(
    at: at,
    title: '${ticket.flightNumber} to $to departs in 3 hours',
    body: "Flying $from → $to. See who's at $from.",
  );
}

class FlightReminder extends Equatable {
  const FlightReminder({
    required this.at,
    required this.title,
    required this.body,
  });

  /// When to show it, in UTC.
  final DateTime at;
  final String title;
  final String body;

  @override
  List<Object?> get props => [at, title, body];
}
