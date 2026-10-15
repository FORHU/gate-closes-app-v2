import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/terminal_echo/data/models/terminal_echo_model.dart';

void main() {
  group('TerminalEchoModel parsing and attributes', () {
    test('reads the audio and sender from the nested API file/user', () {
      final model = TerminalEchoModel.fromJson(const {
        'data': {
          '_id': 'e1',
          'file': {
            'fileUrl': 'https://cdn.example.com/a.m4a',
            'fileName': 'a.m4a',
            'metaData': {
              'audioDuration': 7.5,
              'waveformData': [0.2, 0.8],
            },
          },
          'user': {'username': 'test_superadmin', 'picture': 'avatar:chick'},
        },
      });

      expect(model.senderPicture, 'avatar:chick');
      expect(model.isVoiceMemo, isTrue);
      expect(model.fileUrl, 'https://cdn.example.com/a.m4a');
      expect(model.fileName, 'a.m4a');
      expect(model.audioDuration, 7.5);
      expect(model.waveformData, [0.2, 0.8]);
      expect(model.senderUsername, 'test_superadmin');
    });

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

    test("reads the viewer's reaction from currentUserReactions", () {
      final model = TerminalEchoModel.fromJson(const {
        'id': 'e1',
        'senderId': 'u1',
        'textMessage': '',
        'airportIata': 'MNL',
        'createdAt': '2026-10-13T08:00:00.000Z',
        'currentUserReactions': ['haha'],
      });

      expect(model.userReaction, 'haha');
    });
  });
}
