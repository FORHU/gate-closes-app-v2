import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/airport/data/models/airport_model.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';

void main() {
  group('AirportModel parsing & DetectionState mapping', () {
    test('parses inside airport boundary result as insideAirport state', () {
      final json = {
        'data': {
          '_id': '64f1a2b3c4d5e6f7a8b9c0d2',
          'airport': 'Singapore Changi Airport',
          'iata': 'SIN',
          'icao': 'WSSS',
          'countryCode': 'SG',
          'insideRadius': true,
          'distanceKm': 0.25,
        },
      };

      final model = AirportModel.fromJson(json);

      expect(model.id, '64f1a2b3c4d5e6f7a8b9c0d2');
      expect(model.name, 'Singapore Changi Airport');
      expect(model.iata, 'SIN');
      expect(model.icao, 'WSSS');
      expect(model.countryCode, 'SG');
      expect(model.insideBoundary, isTrue);
      expect(model.detectionState, AirportDetectionState.insideAirport);
    });

    test('marks nearby airport within 10km as approaching state', () {
      final json = {
        'data': {
          '_id': '64f1a2b3c4d5e6f7a8b9c0d3',
          'airport': 'London Heathrow Airport',
          'iata': 'LHR',
          'icao': 'EGLL',
          'insideRadius': false,
          'distanceKm': 6.8,
        },
      };

      final model = AirportModel.fromJson(json);

      expect(model.iata, 'LHR');
      expect(model.insideBoundary, isFalse);
      expect(model.detectionState, AirportDetectionState.approaching);
    });

    test('marks distant airport as outsideAirport state', () {
      final json = {
        'data': {
          '_id': '64f1a2b3c4d5e6f7a8b9c0d4',
          'airport': 'Tokyo Haneda Airport',
          'iata': 'HND',
          'insideRadius': false,
          'distanceKm': 45.2,
        },
      };

      final model = AirportModel.fromJson(json);

      expect(model.iata, 'HND');
      expect(model.insideBoundary, isFalse);
      expect(model.detectionState, AirportDetectionState.outsideAirport);
    });
  });
}
