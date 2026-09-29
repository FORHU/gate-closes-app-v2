import 'package:gate_closes/features/connections/data/models/connection_model.dart';
import 'package:gate_closes/features/connections/domain/entities/connection_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectionModel parsing against gate-closes-api contracts', () {
    // Shape returned by ConversationSvc.shapeConversationForUser —
    // gate-closes-api/src/services/conversation.service.ts.
    test('parses a conversation with an unread destination-thread match', () {
      final json = {
        '_id': 'convo123',
        'type': 'destination_thread',
        'participants': ['user1', 'user2'],
        'dmKey': 'destination_thread:user1:user2',
        'participantsDetail': [
          {'_id': 'user1', 'username': 'me', 'gender': 'female', 'name': 'me'},
          {
            '_id': 'user2',
            'username': 'traveler_99',
            'gender': 'male',
            'name': 'traveler_99',
          },
        ],
        'otherUser': {
          '_id': 'user2',
          'username': 'traveler_99',
          'gender': 'male',
          'name': 'traveler_99',
        },
        'lastEventType': 'message_sent',
        'lastEventAt': '2026-09-23T10:00:00.000Z',
        'lastEventActorId': 'user2',
        'lastEventActorName': 'traveler_99',
        'lastEventText': 'See you at the gate!',
        'lastReadAt': null,
        'hasUnread': true,
      };

      final model = ConnectionModel.fromJson(json);

      expect(model.id, 'convo123');
      expect(model.type, ConnectionType.destinationThread);
      expect(model.participantIds, ['user1', 'user2']);
      expect(model.dmKey, 'destination_thread:user1:user2');
      expect(model.otherUserId, 'user2');
      expect(model.otherUserName, 'traveler_99');
      expect(model.lastEventText, 'See you at the gate!');
      expect(model.lastEventAt, DateTime.parse('2026-09-23T10:00:00.000Z'));
      expect(model.hasUnread, isTrue);
      // No avatar field exists on the backend's participant projection.
      expect(model.otherUserAvatar, isNull);
    });

    test('defaults to parallel_soul, no otherUser, and unread=false', () {
      final json = {
        '_id': 'convo456',
        'participants': <dynamic>[],
        'dmKey': 'parallel_soul:user1:user3',
      };

      final model = ConnectionModel.fromJson(json);

      expect(model.type, ConnectionType.parallelSoul);
      expect(model.otherUserId, isNull);
      expect(model.otherUserName, isNull);
      expect(model.hasUnread, isFalse);
      expect(model.lastEventAt, isNull);
    });
  });
}
