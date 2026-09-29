import 'package:gate_closes/features/connections/data/models/conversation_message_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConversationMessageModel parsing against gate-closes-api contracts',
      () {
    // Shape returned by ConversationMessageRepo.listByConversationId /
    // findByIdWithDetails — gate-closes-api/src/repositories/
    // conversation.message.repository.ts.
    test('parses a voice-memo message with a resolved file and sender', () {
      final json = {
        '_id': 'msg1',
        'conversationId': 'convo123',
        'senderId': 'user456',
        'textMessage': '',
        'reactions': {'like': 2, 'love': 0},
        'currentUserReactions': ['like'],
        'createdAt': '2026-09-23T10:00:00.000Z',
        'file': {
          '_id': 'file1',
          'fileUrl': 'https://s3.example.com/voice1.m4a',
          'fileName': 'voice1.m4a',
          'metaData': {
            'audioDuration': 7.2,
            'waveformData': [0.1, 0.4, 0.9],
          },
        },
        'sender': {'_id': 'user456', 'username': 'traveler_99', 'gender': 'm'},
      };

      final model = ConversationMessageModel.fromJson(json);

      expect(model.id, 'msg1');
      expect(model.conversationId, 'convo123');
      expect(model.senderId, 'user456');
      expect(model.isVoiceMemo, isTrue);
      expect(model.fileUrl, 'https://s3.example.com/voice1.m4a');
      expect(model.fileName, 'voice1.m4a');
      expect(model.audioDuration, 7.2);
      expect(model.waveformData, [0.1, 0.4, 0.9]);
      expect(model.reactions, {'like': 2, 'love': 0});
      expect(model.currentUserReactions, ['like']);
      expect(model.senderUsername, 'traveler_99');
      expect(model.createdAt, DateTime.parse('2026-09-23T10:00:00.000Z'));
    });

    test('parses a plain text message with no file/reactions', () {
      final json = {
        '_id': 'msg2',
        'conversationId': 'convo123',
        'senderId': 'user789',
        'textMessage': 'See you at the gate!',
      };

      final model = ConversationMessageModel.fromJson(json);

      expect(model.textMessage, 'See you at the gate!');
      expect(model.isVoiceMemo, isFalse);
      expect(model.fileUrl, isNull);
      expect(model.audioDuration, 0);
      expect(model.waveformData, isEmpty);
      expect(model.reactions, isEmpty);
      expect(model.currentUserReactions, isEmpty);
      expect(model.senderUsername, isNull);
    });

    test('isMine compares senderId to the current user id', () {
      final model = ConversationMessageModel.fromJson(const {
        '_id': 'msg3',
        'conversationId': 'convo123',
        'senderId': 'user456',
      });

      expect(model.isMine('user456'), isTrue);
      expect(model.isMine('someoneElse'), isFalse);
    });
  });
}
