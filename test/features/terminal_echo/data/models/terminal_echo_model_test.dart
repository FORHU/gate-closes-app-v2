import 'package:gate_closes/features/terminal_echo/data/models/terminal_echo_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TerminalEchoModel parsing and attributes', () {
    test('parses voice memo echo with waveforms and reactions', () {
      final json = {
        'data': {
          '_id': 'echo123',
          'senderId': 'user456',
          'textMessage': 'Gate 42 is boarding now!',
          'airportIata': 'SIN',
          'fileUrl': 'https://s3.example.com/audio1.m4a',
          'fileName': 'audio1.m4a',
          'audioDuration': 9.5,
          'waveformData': [0.1, 0.5, 0.9, 0.3],
          'countListens': 15,
          'countReactLike': 4,
          'countReactLove': 2,
          'createdAt': '2026-09-23T10:00:00.000Z',
          'senderUsername': 'traveler_99',
        },
      };

      final model = TerminalEchoModel.fromJson(json);

      expect(model.id, 'echo123');
      expect(model.senderId, 'user456');
      expect(model.textMessage, 'Gate 42 is boarding now!');
      expect(model.airportIata, 'SIN');
      expect(model.isVoiceMemo, isTrue);
      expect(model.audioDuration, 9.5);
      expect(model.waveformData, [0.1, 0.5, 0.9, 0.3]);
      expect(model.countListens, 15);
      expect(model.totalReactions, 6);
      expect(model.senderUsername, 'traveler_99');
    });

    test('parses pure text echo with zero audio attributes', () {
      final json = {
        'data': {
          '_id': 'echo789',
          'senderId': 'user101',
          'textMessage': 'Any good coffee near Terminal 3?',
          'airportName': 'LHR',
          'createdAt': '2026-09-23T11:00:00.000Z',
        },
      };

      final model = TerminalEchoModel.fromJson(json);

      expect(model.id, 'echo789');
      expect(model.airportIata, 'LHR');
      expect(model.isVoiceMemo, isFalse);
      expect(model.audioDuration, 0.0);
      expect(model.waveformData, isEmpty);
      expect(model.totalReactions, 0);
    });
  });
}
