import 'package:flutter_template/features/boarding_pass/domain/parsers/bcbp_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BcbpParser Unit Tests (IATA Resolution 791)', () {
    test('parses valid IATA BCBP standard string correctly', () {
      // Sample standard 1-leg boarding pass:
      // M1DOE/JOHN            E1234567SINLHRBA 0012 105Y012A0001
      // Length >= 52 chars
      const raw = 'M1DOE/JOHN            E1234567SINLHRBA 0012 105Y012A0001'
          ' 100';

      final result = BcbpParser.parse(raw);

      expect(result, isNotNull);
      expect(result!.passengerName, 'DOE JOHN');
      expect(result.pnr, '1234567');
      expect(result.fromAirport, 'SIN');
      expect(result.toAirport, 'LHR');
      expect(result.airline, 'BA');
      expect(result.flightNumber, '0012');
      expect(result.seat, '012A');
      expect(result.date, contains('-'));
    });

    test('returns null for non-BCBP strings or invalid header', () {
      expect(BcbpParser.parse('HELLO WORLD'), isNull);
      expect(BcbpParser.parse('A1DOE/JOHN'), isNull);
      expect(BcbpParser.parse(''), isNull);
    });

    test('returns null for truncated string missing essential fields', () {
      expect(BcbpParser.parse('M1DOE/JOHN'), isNull);
    });

    test('returns null for invalid Julian day numbers', () {
      // Julian day 999 is invalid (> 366)
      const rawWithInvalidDay =
          'M1SMITH/ALICE         EABCDEFGJFKLAXAA 0100 999Y001B0001';
      expect(BcbpParser.parse(rawWithInvalidDay), isNull);
    });

    test('parses BCBP with empty seat field gracefully', () {
      const raw = 'M1BROWN/CHARLIE       EXYZ1234NRTCDGAF 0275 050';
      final result = BcbpParser.parse(raw);

      expect(result, isNotNull);
      expect(result!.passengerName, 'BROWN CHARLIE');
      expect(result.pnr, 'XYZ1234');
      expect(result.fromAirport, 'NRT');
      expect(result.toAirport, 'CDG');
      expect(result.airline, 'AF');
      expect(result.flightNumber, '0275');
      expect(result.seat, isNull);
    });
  });
}
