import 'package:flutter_template/features/boarding_pass/domain/heuristics/boarding_pass_ocr_heuristics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoardingPassOcrHeuristics', () {
    test('extracts flight number correctly', () {
      const sampleText = 'BOARDING PASS SQ 321 SINGAPORE AIRLINES';
      final guess = BoardingPassOcrHeuristics.guessFields(sampleText);
      expect(guess.flightNumber, 'SQ321');
    });

    test('extracts airport codes while filtering out noise words', () {
      const sampleText = 'FROM SIN TO NRT FLIGHT GA 881 GATE 12 SEAT 24A';
      final guess = BoardingPassOcrHeuristics.guessFields(sampleText);
      expect(guess.fromAirport, 'SIN');
      expect(guess.toAirport, 'NRT');
      expect(guess.flightNumber, 'GA881');
    });

    test('extracts departure date with month name', () {
      final currentYear = DateTime.now().year;
      const sampleText = 'FLIGHT DL 142 DATE 15 OCT SEAT 14B';
      final guess = BoardingPassOcrHeuristics.guessFields(sampleText);
      expect(guess.departureDateTime, '$currentYear-10-15');
    });

    test('extracts ISO departure date', () {
      const sampleText = 'FLIGHT BA 123 2026-11-20 DEPARTURE LHR JFK';
      final guess = BoardingPassOcrHeuristics.guessFields(sampleText);
      expect(guess.departureDateTime, '2026-11-20');
      expect(guess.fromAirport, 'LHR');
      expect(guess.toAirport, 'JFK');
    });
  });
}
