import 'package:flutter_template/core/errors/failure.dart';
import 'package:flutter_template/features/connections/domain/entities/conversation_message_entity.dart';
import 'package:fpdart/fpdart.dart';

abstract class MessagesRepository {
  /// Lists messages for a conversation, newest-first (matches the backend's
  /// `listByConversationId` sort — callers reverse for display order).
  Future<Either<Failure, List<ConversationMessageEntity>>> getMessages({
    required String conversationId,
    int limit = 50,
  });

  /// Sends a text message. Voice-memo composition isn't wired up yet — the
  /// backend supports it (`fileUrl`/`fileName`/`audioDuration`/
  /// `waveformData`), but recording UI is out of this phase's scope.
  Future<Either<Failure, ConversationMessageEntity>> sendTextMessage({
    required String conversationId,
    required String textMessage,
  });

  /// Toggles a reaction on a message. `reaction` must be one of the 6
  /// backend-supported keys: like, love, haha, wow, sad, angry.
  Future<Either<Failure, void>> updateReaction({
    required String conversationId,
    required String messageId,
    required String reaction,
  });

  /// Marks the conversation read up to its latest event. This only updates
  /// *this* user's read state — the backend has no realtime broadcast for
  /// "the other participant read your message", so there is no live
  /// read-receipt indicator to show for the other side.
  Future<Either<Failure, void>> markRead({required String conversationId});
}
