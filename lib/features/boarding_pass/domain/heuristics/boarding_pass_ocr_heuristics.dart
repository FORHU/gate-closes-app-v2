/// Best-effort field guesser for on-device OCR text recognition output.
/// Mirrors `boardingPassOcrHeuristics.ts` in the reference app.
class OcrFieldGuess {
  const OcrFieldGuess({
    this.flightNumber,
    this.fromAirport,
    this.toAirport,
    this.departureDateTime,
  });

  final String? flightNumber;
  final String? fromAirport;
  final String? toAirport;
  final String? departureDateTime;
}

class BoardingPassOcrHeuristics {
  BoardingPassOcrHeuristics._();

  static const Map<String, int> _months = {
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };

  static const Set<String> _nonAirportTokens = {
    'THE',
    'AND',
    'FOR',
    'YOU',
    'ARE',
    'GATE',
    'SEAT',
    'FROM',
    'BOARDING',
    'CLASS',
    'ZONE',
    'PASS',
    'FLIGHT',
    'DATE',
    'TIME',
    'PNR',
    'ETC',
  };

  static String? guessFlightNumber(String text) {
    final regex = RegExp(r'\b([A-Z]{2})\s?-?\s?(\d{2,4})\b');
    final match = regex.firstMatch(text);
    if (match != null) {
      return '${match.group(1)}${match.group(2)}';
    }
    return null;
  }

  static (String?, String?) guessAirportCodes(String text) {
    final regex = RegExp(r'\b[A-Z]{3}\b');
    final matches = regex.allMatches(text);
    final candidates = <String>[];

    for (final match in matches) {
      final code = match.group(0)!;
      if (!_nonAirportTokens.contains(code) && !candidates.contains(code)) {
        candidates.add(code);
      }
    }

    final from = candidates.isNotEmpty ? candidates[0] : null;
    final to = candidates.length > 1 ? candidates[1] : null;
    return (from, to);
  }

  static String? guessDepartureDate(String text) {
    final isoRegex = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');
    final isoMatch = isoRegex.firstMatch(text);
    if (isoMatch != null) {
      return '${isoMatch.group(1)}-${isoMatch.group(2)}-${isoMatch.group(3)}';
    }

    final monthNames = _months.keys.join('|');
    final dayMonthRegex = RegExp(
      '\\b(\\d{1,2})\\s?($monthNames)\\b',
      caseSensitive: false,
    );
    final dayMonthMatch = dayMonthRegex.firstMatch(text);
    if (dayMonthMatch != null) {
      final day = int.tryParse(dayMonthMatch.group(1)!);
      final month = _months[dayMonthMatch.group(2)!.toUpperCase()];
      if (day != null && month != null) {
        final year = DateTime.now().year;
        final dStr = day.toString().padLeft(2, '0');
        final mStr = month.toString().padLeft(2, '0');
        return '$year-$mStr-$dStr';
      }
    }

    return null;
  }

  static OcrFieldGuess guessFields(String recognizedText) {
    final text = recognizedText.toUpperCase();
    final (from, to) = guessAirportCodes(text);

    return OcrFieldGuess(
      flightNumber: guessFlightNumber(text),
      fromAirport: from,
      toAirport: to,
      departureDateTime: guessDepartureDate(text),
    );
  }
}
