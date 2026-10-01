import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/connections/data/datasources/conversation_socket_service.dart';
import 'package:gate_closes/features/connections/domain/entities/connection_entity.dart';
import 'package:gate_closes/features/connections/domain/entities/conversation_message_entity.dart';
import 'package:gate_closes/features/connections/domain/repositories/connections_repository.dart';
import 'package:gate_closes/features/connections/domain/repositories/messages_repository.dart';
import 'package:gate_closes/features/connections/presentation/controllers/connections_controller.dart';
import 'package:gate_closes/features/connections/presentation/controllers/message_thread_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/signed_in_auth.dart';

class MockConnectionsRepository extends Mock implements ConnectionsRepository {}

class MockMessagesRepository extends Mock implements MessagesRepository {}

class _FakeSocket extends Fake implements ConversationSocketService {
  int connects = 0;

  @override
  void connect({
    String? conversationId,
    void Function(Map<String, dynamic> message)? onMessageReceived,
    void Function(Map<String, dynamic> reaction)? onReactionUpdated,
    void Function(Map<String, dynamic> update)? onConversationUpdated,
  }) =>
      connects++;

  @override
  void disconnect() {}
}

void main() {
  late MockConnectionsRepository connections;
  late MockMessagesRepository messages;
  late _FakeSocket socket;
  late ProviderContainer container;

  const otherUser = 'u2';
  const existing = ConnectionEntity(
    id: 'c1',
    type: ConnectionType.parallelSoul,
    participantIds: ['u1', otherUser],
    dmKey: 'dm',
    otherUserId: otherUser,
    otherUserName: 'jane',
  );
  const sent = ConversationMessageEntity(
    id: 'm1',
    conversationId: 'c1',
    senderId: 'u1',
    fileUrl: 'https://s3/x.m4a',
  );

  MessageThreadController controller() =>
      container.read(messageThreadControllerProvider.notifier);
  MessageThreadState state() => container.read(messageThreadControllerProvider);

  Future<bool> sendVoice() => controller().sendVoice(
        fileUrl: 'https://s3/x.m4a',
        audioDuration: 1200,
        waveformData: const [0.1, 0.5],
      );

  setUpAll(() => registerFallbackValue(ConnectionType.parallelSoul));

  setUp(() {
    connections = MockConnectionsRepository();
    messages = MockMessagesRepository();
    socket = _FakeSocket();
    container = ProviderContainer(
      overrides: [
        signedInAuthOverride,
        connectionsRepositoryProvider.overrideWithValue(connections),
        messagesRepositoryProvider.overrideWithValue(messages),
        conversationSocketFactoryProvider.overrideWithValue(() => socket),
      ],
    );
    when(
      () => messages.getMessages(conversationId: any(named: 'conversationId')),
    ).thenAnswer((_) async => const Right([]));
    when(
      () => messages.markRead(conversationId: any(named: 'conversationId')),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => messages.sendVoiceMessage(
        conversationId: any(named: 'conversationId'),
        fileUrl: any(named: 'fileUrl'),
        audioDuration: any(named: 'audioDuration'),
        waveformData: any(named: 'waveformData'),
        fileName: any(named: 'fileName'),
      ),
    ).thenAnswer((_) async => const Right(sent));
  });

  tearDown(() => container.dispose());

  void listConnections(List<ConnectionEntity> list) => when(
        () => connections.getConnections(type: any(named: 'type')),
      ).thenAnswer((_) async => Right(list));

  test('opens the existing conversation instead of a draft', () async {
    listConnections([existing]);

    await controller()
        .openDraft(type: ConnectionType.parallelSoul, otherUserId: otherUser);

    expect(state().isDraft, isFalse);
    expect(state().connection, existing);
    verify(() => messages.getMessages(conversationId: 'c1')).called(1);
  });

  test('an existing conversation of another type does not count', () async {
    listConnections([existing]);

    await controller().openDraft(
      type: ConnectionType.batonTouch,
      otherUserId: otherUser,
    );

    expect(state().isDraft, isTrue);
    expect(state().draftType, ConnectionType.batonTouch);
  });

  test('no conversation exists: a draft, created only on first send', () async {
    listConnections([]);
    when(
      () => connections.createConnection(
        type: any(named: 'type'),
        otherUserId: any(named: 'otherUserId'),
      ),
    ).thenAnswer((_) async => const Right(existing));

    await controller()
        .openDraft(type: ConnectionType.parallelSoul, otherUserId: otherUser);
    expect(state().isDraft, isTrue);
    verifyNever(
      () => connections.createConnection(
        type: any(named: 'type'),
        otherUserId: any(named: 'otherUserId'),
      ),
    );

    expect(await sendVoice(), isTrue);

    verify(
      () => connections.createConnection(
        type: ConnectionType.parallelSoul,
        otherUserId: otherUser,
      ),
    ).called(1);
    verify(
      () => messages.sendVoiceMessage(
        conversationId: 'c1',
        fileUrl: any(named: 'fileUrl'),
        audioDuration: any(named: 'audioDuration'),
        waveformData: any(named: 'waveformData'),
        fileName: any(named: 'fileName'),
      ),
    ).called(1);
    expect(state().isDraft, isFalse);
    expect(state().connection, existing);
    expect(state().messages, [sent]);
    expect(socket.connects, 1);
  });

  test('"already exists" on create: uses the existing conversation', () async {
    var lists = 0;
    when(
      () => connections.getConnections(type: any(named: 'type')),
    ).thenAnswer(
      (_) async => Right(lists++ == 0 ? const [] : const [existing]),
    );
    when(
      () => connections.createConnection(
        type: any(named: 'type'),
        otherUserId: any(named: 'otherUserId'),
      ),
    ).thenAnswer(
      (_) async => const Left(ServerFailure('Conversation already exists.')),
    );

    await controller()
        .openDraft(type: ConnectionType.parallelSoul, otherUserId: otherUser);

    expect(await sendVoice(), isTrue);
    expect(state().connection, existing);
    verify(
      () => messages.sendVoiceMessage(
        conversationId: 'c1',
        fileUrl: any(named: 'fileUrl'),
        audioDuration: any(named: 'audioDuration'),
        waveformData: any(named: 'waveformData'),
        fileName: any(named: 'fileName'),
      ),
    ).called(1);
  });

  test('an ineligible pairing surfaces the error and sends nothing', () async {
    listConnections([]);
    when(
      () => connections.createConnection(
        type: any(named: 'type'),
        otherUserId: any(named: 'otherUserId'),
      ),
    ).thenAnswer(
      (_) async =>
          const Left(ServerFailure('Users are not on the same route.')),
    );

    await controller()
        .openDraft(type: ConnectionType.parallelSoul, otherUserId: otherUser);

    expect(await sendVoice(), isFalse);
    expect(state().isDraft, isTrue);
    expect(state().isSending, isFalse);
    expect(state().error, 'Users are not on the same route.');
    verifyNever(
      () => messages.sendVoiceMessage(
        conversationId: any(named: 'conversationId'),
        fileUrl: any(named: 'fileUrl'),
        audioDuration: any(named: 'audioDuration'),
        waveformData: any(named: 'waveformData'),
        fileName: any(named: 'fileName'),
      ),
    );
  });

  test('sending with no thread open does not stay "sending"', () async {
    expect(await controller().sendText('hi'), isFalse);
    expect(state().isSending, isFalse);
  });
}
