import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/terminal_echo/data/models/terminal_echo_reply_model.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_reply_entity.dart';
import 'package:gate_closes/features/terminal_echo/domain/repositories/terminal_echo_reply_repository.dart';
import 'package:fpdart/fpdart.dart';

class TerminalEchoReplyRepositoryImpl implements TerminalEchoReplyRepository {
  const TerminalEchoReplyRepositoryImpl(this._api);

  final ApiService _api;

  @override
  Future<Either<Failure, List<TerminalEchoReplyEntity>>> getReplies(
    String terminalEchoId,
  ) async {
    try {
      final response = await _api.get(
        ApiEndpoints.terminalEchoReply,
        query: {'terminalEchoId': terminalEchoId},
      );

      final rawData = (response as Map)['data'];
      if (rawData is! List) return const Right([]);

      final list = rawData
          .whereType<Map<String, dynamic>>()
          .map(TerminalEchoReplyModel.fromJson)
          .toList();

      return Right(list);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TerminalEchoReplyEntity>> createReply({
    required String terminalEchoId,
    String? fileUrl,
    String? fileName,
    String? textMessage,
    double audioDuration = 0,
    List<double> waveformData = const [],
  }) async {
    try {
      final payload = <String, dynamic>{
        'terminalEchoId': terminalEchoId,
        'fileUrl': fileUrl ?? '',
        'fileName': fileName ?? '',
        'textMessage': textMessage ?? '',
        'audioDuration': audioDuration,
        'waveformData': waveformData,
      };

      final response = await _api.post(ApiEndpoints.terminalEchoReply, payload);
      final rawData = (response as Map)['data'];
      final jsonMap = rawData is Map<String, dynamic>
          ? rawData
          : (rawData is Map)
              ? rawData.cast<String, dynamic>()
              : <String, dynamic>{'_id': response['insertedId']};
      final model = TerminalEchoReplyModel.fromJson(jsonMap);
      return Right(model);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateReaction({
    required String replyId,
    required EchoReactionType reaction,
    required bool isCurrentlyReacted,
  }) async {
    try {
      final action = isCurrentlyReacted ? 'decrement' : 'increment';
      await _api.patch(
        ApiEndpoints.terminalEchoReplyReaction(replyId),
        {'reaction': reaction.name, 'action': action},
      );
      return const Right(null);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> incrementListen(String replyId) async {
    try {
      await _api.patch(ApiEndpoints.terminalEchoReplyListen(replyId), {});
      return const Right(null);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
