import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_reply_entity.dart';

abstract class TerminalEchoReplyRepository {
  /// Fetches all replies for a specific Terminal Echo thread.
  Future<Either<Failure, List<TerminalEchoReplyEntity>>> getReplies(
    String terminalEchoId,
  );

  /// Publishes a reply to an existing Terminal Echo.
  /// Can be voice memo or text message (or both).
  Future<Either<Failure, TerminalEchoReplyEntity>> createReply({
    required String terminalEchoId,
    String? fileUrl,
    String? fileName,
    String? textMessage,
    double audioDuration = 0,
    List<double> waveformData = const [],
  });

  /// Toggles or updates an emoji reaction on a reply.
  Future<Either<Failure, void>> updateReaction({
    required String replyId,
    required EchoReactionType reaction,
    required bool isCurrentlyReacted,
  });

  /// Increments listen count when an audio reply reaches >=70% played.
  Future<Either<Failure, void>> incrementListen(String replyId);
}
