import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/connections/data/datasources/conversation_socket_service.dart';
import 'package:gate_closes/features/connections/data/models/conversation_message_model.dart';
import 'package:gate_closes/features/connections/data/repositories/messages_repository_impl.dart';
import 'package:gate_closes/features/connections/domain/entities/connection_entity.dart';
import 'package:gate_closes/features/connections/domain/entities/conversation_message_entity.dart';
import 'package:gate_closes/features/connections/domain/repositories/messages_repository.dart';
import 'package:gate_closes/features/connections/presentation/controllers/connections_controller.dart';

// --- Dependency wiring ---

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return MessagesRepositoryImpl(ref.watch(apiServiceProvider));
});

/// Builds the realtime socket for an open thread. A provider so tests can
/// swap in a fake instead of opening a real connection.
final conversationSocketFactoryProvider =
    Provider<ConversationSocketService Function()>((ref) {
  return () => ConversationSocketService(
        readToken: ref.read(storageServiceProvider).readToken,
        revalidateSession: () =>
            ref.read(authControllerProvider.notifier).refreshAuth(),
      );
});

// --- State ---

class MessageThreadState extends Equatable {
  const MessageThreadState({
    this.isLoading = false,
    this.isSending = false,
    // Newest-last, ready for a bottom-anchored chat list.
    this.messages = const [],
    this.error,
    this.connection,
    this.draftType,
  });

  final bool isLoading;
  final bool isSending;
  final List<ConversationMessageEntity> messages;
  final String? error;

  /// The open conversation, once known (always set for a started draft).
  final ConnectionEntity? connection;

  /// Non-null while this is a draft: no conversation exists yet, and one of
  /// this type is created when the first message is sent.
  final ConnectionType? draftType;

  bool get isDraft => draftType != null;

  MessageThreadState copyWith({
    bool? isLoading,
    bool? isSending,
    List<ConversationMessageEntity>? messages,
    String? error,
    ConnectionEntity? connection,
    bool clearDraft = false,
  }) {
    return MessageThreadState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      messages: messages ?? this.messages,
      // Intentionally not `error ?? this.error`: passing null clears it.
      error: error,
      connection: connection ?? this.connection,
      draftType: clearDraft ? null : draftType,
    );
  }

  @override
  List<Object?> get props =>
      [isLoading, isSending, messages, error, connection, draftType];
}

// --- Controller ---

/// Holds the currently-open thread. Riverpod 3's manual (non-codegen) API
/// doesn't support `.family` for [Notifier] the way this codebase's other
/// controllers are written, so — mirroring `TerminalEchoController`'s
/// `loadFeed(airportIata)` pattern — this is a single instance representing
/// "whichever thread is currently open"; the page calls [openThread]
/// explicitly instead of the provider being parameterized.
class MessageThreadController extends Notifier<MessageThreadState> {
  ConversationSocketService? _socketService;
  String? _conversationId;
  ({ConnectionType type, String otherUserId})? _draft;

  @override
  MessageThreadState build() {
    // Reset (and drop the socket) whenever the signed-in user changes.
    ref
      ..watch(authControllerProvider.select((s) => s.user?.id))
      ..onDispose(() {
        _socketService?.disconnect();
        _socketService = null;
        _conversationId = null;
        _draft = null;
      });
    return const MessageThreadState();
  }

  Future<void> openThread(
    String conversationId, {
    ConnectionEntity? connection,
  }) async {
    _conversationId = conversationId;
    _draft = null;
    state = MessageThreadState(isLoading: true, connection: connection);

    final repo = ref.read(messagesRepositoryProvider);
    final result = await repo.getMessages(conversationId: conversationId);
    // The user may have opened another thread while this one was loading.
    if (!ref.mounted || _conversationId != conversationId) return;

    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (messages) {
        // Backend returns newest-first; reverse for a bottom-anchored list.
        state = MessageThreadState(
          messages: messages.reversed.toList(),
          connection: state.connection,
        );
        _initSocket(conversationId);
        unawaited(repo.markRead(conversationId: conversationId));
      },
    );
  }

  /// Opens the [type] conversation with [otherUserId]: the existing one if
  /// there is one, otherwise a draft that is only created on the first send,
  /// so the other traveler never sees an empty conversation. Mirrors the Expo
  /// map's "start conversation".
  ///
  /// The existing conversation is found in the user's own list because
  /// `GET /conversations/existence` returns only a boolean, never the id.
  Future<void> openDraft({
    required ConnectionType type,
    required String otherUserId,
  }) async {
    final draft = (type: type, otherUserId: otherUserId);
    _draft = draft;
    _conversationId = null;
    _socketService?.disconnect();
    _socketService = null;
    state = MessageThreadState(isLoading: true, draftType: type);

    final existing = await _findExisting(type, otherUserId);
    // The user may have opened another thread meanwhile.
    if (!ref.mounted || _draft != draft) return;
    if (existing != null) {
      await openThread(existing.id, connection: existing);
      return;
    }
    state = MessageThreadState(draftType: type);
  }

  Future<ConnectionEntity?> _findExisting(
    ConnectionType type,
    String otherUserId,
  ) async {
    final result = await ref
        .read(connectionsRepositoryProvider)
        .getConnections(type: type);
    return result.fold(
      (_) => null,
      (all) => all
          .where((c) => c.type == type && c.otherUserId == otherUserId)
          .firstOrNull,
    );
  }

  /// The id to send to, creating the drafted conversation first if needed.
  /// Null (with [MessageThreadState.error] set) if it couldn't be created,
  /// e.g. the API rejects the pairing as ineligible.
  Future<String?> _ensureConversation() async {
    final existingId = _conversationId;
    if (existingId != null) return existingId;
    final draft = _draft;
    if (draft == null) {
      // No thread open (e.g. reset by a sign-out): nothing to send to.
      state = state.copyWith(isSending: false);
      return null;
    }

    final created =
        await ref.read(connectionsRepositoryProvider).createConnection(
              type: draft.type,
              otherUserId: draft.otherUserId,
            );
    String? error;
    var connection = created.fold<ConnectionEntity?>(
      (failure) {
        error = failure.message;
        return null;
      },
      (c) => c,
    );
    // "Conversation already exists" (409): started meanwhile, e.g. by the
    // other traveler or on another device. Use that one.
    connection ??= await _findExisting(draft.type, draft.otherUserId);
    if (!ref.mounted || _draft != draft) return null;

    if (connection == null) {
      state = state.copyWith(
        isSending: false,
        error: error ?? 'Could not start this conversation.',
      );
      return null;
    }
    _draft = null;
    _conversationId = connection.id;
    state = state.copyWith(connection: connection, clearDraft: true);
    _initSocket(connection.id);
    return connection.id;
  }

  void _initSocket(String conversationId) {
    _socketService?.disconnect();
    _socketService = ref.read(conversationSocketFactoryProvider)();

    _socketService!.connect(
      conversationId: conversationId,
      onMessageReceived: (data) {
        final incoming = ConversationMessageModel.fromJson(data);
        if (state.messages.any((m) => m.id == incoming.id)) return;
        state = state.copyWith(messages: [...state.messages, incoming]);
      },
      onReactionUpdated: (data) {
        // Payload: {action, messageId, reaction, conversation} — a toggle
        // delta, not a full reactions map (conversation.service.ts
        // updateMessageReaction).
        final messageId = data['messageId']?.toString();
        final reaction = data['reaction']?.toString();
        final action = data['action']?.toString();
        if (messageId == null || reaction == null || action == null) return;

        final delta = action == 'increment' ? 1 : -1;
        state = state.copyWith(
          messages: [
            for (final m in state.messages)
              if (m.id != messageId)
                m
              else
                m.copyWith(
                  reactions: {
                    ...m.reactions,
                    reaction: ((m.reactions[reaction] ?? 0) + delta)
                        .clamp(0, 1 << 31),
                  }..removeWhere((_, count) => count == 0),
                ),
          ],
        );
      },
    );
  }

  /// Sends a text message and appends it optimistically; the realtime echo
  /// via socket is de-duplicated by id in `onMessageReceived`.
  Future<bool> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    state = state.copyWith(isSending: true);
    final conversationId = await _ensureConversation();
    if (conversationId == null) return false;
    final repo = ref.read(messagesRepositoryProvider);
    final result = await repo.sendTextMessage(
      conversationId: conversationId,
      textMessage: trimmed,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isSending: false, error: failure.message);
        return false;
      },
      (sent) {
        if (!state.messages.any((m) => m.id == sent.id)) {
          state = state.copyWith(
            isSending: false,
            messages: [...state.messages, sent],
          );
        } else {
          state = state.copyWith(isSending: false);
        }
        return true;
      },
    );
  }

  /// Sends a voice memo message with waveform and audio duration.
  Future<bool> sendVoice({
    required String fileUrl,
    required double audioDuration,
    required List<double> waveformData,
    String? fileName,
  }) async {
    state = state.copyWith(isSending: true);
    final conversationId = await _ensureConversation();
    if (conversationId == null) return false;

    final repo = ref.read(messagesRepositoryProvider);
    final result = await repo.sendVoiceMessage(
      conversationId: conversationId,
      fileUrl: fileUrl,
      audioDuration: audioDuration,
      waveformData: waveformData,
      fileName: fileName,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isSending: false, error: failure.message);
        return false;
      },
      (sent) {
        if (!state.messages.any((m) => m.id == sent.id)) {
          state = state.copyWith(
            isSending: false,
            messages: [...state.messages, sent],
          );
        } else {
          state = state.copyWith(isSending: false);
        }
        return true;
      },
    );
  }

  Future<void> react({required String messageId, required String reaction}) {
    final conversationId = _conversationId;
    if (conversationId == null) return Future.value();

    final repo = ref.read(messagesRepositoryProvider);
    return repo
        .updateReaction(
          conversationId: conversationId,
          messageId: messageId,
          reaction: reaction,
        )
        .then((_) {});
  }
}

final messageThreadControllerProvider =
    NotifierProvider<MessageThreadController, MessageThreadState>(
  MessageThreadController.new,
);
