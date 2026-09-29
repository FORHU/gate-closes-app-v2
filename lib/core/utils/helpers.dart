import 'package:intl/intl.dart';

/// Small pure helpers. UI-specific helpers live in `extensions.dart`.
class Helpers {
  Helpers._();

  /// e.g. "June 18, 2026"
  static String formatDate(DateTime date) => DateFormat.yMMMMd().format(date);

  /// Time-of-day greeting.
  static String greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
