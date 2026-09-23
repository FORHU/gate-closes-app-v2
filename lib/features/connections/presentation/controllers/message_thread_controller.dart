import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/services/storage_service.dart';
import 'package:flutter_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_template/features/connections/data/datasources/conversation_socket_service.dart';
import 'package:flutter_template/features/connections/data/models/conversation_message_model.dart';
import 'package:flutter_template/features/connections/data/repositories/messages_repository_impl.dart';
import 'package:flutter_template/features/connections/domain/entities/conversation_message_entity.dart';
import 'package:flutter_template/features/connections/domain/repositories/messages_repository.dart';

// --- Dependency wiring ---

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return MessagesRepositoryImpl(ref.watch(apiServiceProvider));
});

// --- State ---

class MessageThreadState extends Equatable {
  const MessageThreadState({
    this.isLoading = false,
    this.isSending = false,
    // Newest-last, ready for a bottom-anchored chat list.
    this.messages = const [],
    this.error,
  });

  final bool isLoading;
  final bool isSending;
  final List<ConversationMessageEntity> messages;
  final String? error;

  MessageThreadState copyWith({
    bool? isLoading,
    bool? isSending,
    List<ConversationMessageEntity>? messages,
    String? error,
  }) {
    return MessageThreadState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      messages: messages ?? this.messages,
      // Intentionally not `error ?? this.error`: passing null clears it.
      error: error,
    );
  }

  @override
  List<Object?> get props => [isLoading, isSending, messages, error];
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

  @override
  MessageThreadState build() {
    ref.onDispose(() {
      _socketService?.disconnect();
    });
    return const MessageThreadState();
  }

  Future<void> openThread(String conversationId) async {
    _conversationId = conversationId;
    state = const MessageThreadState(isLoading: true);

    final repo = ref.read(messagesRepositoryProvider);
    final result = await repo.getMessages(conversationId: conversationId);

    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (messages) {
        // Backend returns newest-first; reverse for a bottom-anchored list.
        state = MessageThreadState(messages: messages.reversed.toList());
        _initSocket(conversationId);
        unawaited(repo.markRead(conversationId: conversationId));
      },
    );
  }

  void _initSocket(String conversationId) {
    final token = ref.read(storageServiceProvider).readUserModel()?.token;
    _socketService?.disconnect();
    _socketService = ConversationSocketService(token: token);

    _socketService!.connect(
      conversationId: conversationId,
      onMessageReceived: (data) {
        final incoming = ConversationMessageModel.fromJson(data);
        if (state.messages.any((m) => m.id == incoming.id)) return;
        state = state.copyWith(messages: [...state.messages, incoming]);
      },
      onReactionUpdated: (data) {
        final messageId = (data['messageId'] ?? data['_id'])?.toString();
        if (messageId == null) return;

        final reactionsRaw = data['reactions'];
        final reactions = reactionsRaw is Map
            ? reactionsRaw.map(
                (key, value) =>
                    MapEntry(key.toString(), (value as num).toInt()),
              )
            : <String, int>{};

        final updated = state.messages.map((m) {
          if (m.id != messageId) return m;
          return m.copyWith(reactions: reactions);
        }).toList();

        state = state.copyWith(messages: updated);
      },
    );
  }

  /// Sends a text message and appends it optimistically; the realtime echo
  /// via socket is de-duplicated by id in `onMessageReceived`.
  Future<bool> sendText(String text) async {
    final trimmed = text.trim();
    final conversationId = _conversationId;
    if (trimmed.isEmpty || conversationId == null) return false;

    state = state.copyWith(isSending: true);
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
