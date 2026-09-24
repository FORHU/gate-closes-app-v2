import 'package:flutter_template/core/constants/api_endpoints.dart';
import 'package:flutter_template/core/errors/exceptions.dart';
import 'package:flutter_template/core/errors/failure.dart';
import 'package:flutter_template/core/services/api_service.dart';
import 'package:flutter_template/features/connections/data/models/conversation_message_model.dart';
import 'package:flutter_template/features/connections/domain/entities/conversation_message_entity.dart';
import 'package:flutter_template/features/connections/domain/repositories/messages_repository.dart';
import 'package:fpdart/fpdart.dart';

class MessagesRepositoryImpl implements MessagesRepository {
  const MessagesRepositoryImpl(this._api);

  final ApiService _api;

  @override
  Future<Either<Failure, List<ConversationMessageEntity>>> getMessages({
    required String conversationId,
    int limit = 50,
  }) async {
    try {
      final response = await _api.get(
        ApiEndpoints.conversationMessages(conversationId),
        query: {'limit': limit},
      );

      final rawData = (response as Map)['data'];
      if (rawData is! List) return const Right([]);

      final list = rawData
          .whereType<Map<String, dynamic>>()
          .map(ConversationMessageModel.fromJson)
          .toList();

      return Right(list);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ConversationMessageEntity>> sendTextMessage({
    required String conversationId,
    required String textMessage,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.conversationMessages(conversationId),
        {'textMessage': textMessage},
      );

      final rawData = (response as Map)['data'];
      final model = ConversationMessageModel.fromJson(
        (rawData as Map).cast<String, dynamic>(),
      );

      return Right(model);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ConversationMessageEntity>> sendVoiceMessage({
    required String conversationId,
    required String fileUrl,
    required double audioDuration,
    required List<double> waveformData,
    String? fileName,
  }) async {
    try {
      final payload = <String, dynamic>{
        'fileUrl': fileUrl,
        'audioDuration': (audioDuration * 1000).toInt(),
        'waveformData': waveformData,
      };
      if (fileName != null) {
        payload['fileName'] = fileName;
      }

      final response = await _api.post(
        ApiEndpoints.conversationMessages(conversationId),
        payload,
      );

      final rawData = (response as Map)['data'];
      final model = ConversationMessageModel.fromJson(
        (rawData as Map).cast<String, dynamic>(),
      );

      return Right(model);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateReaction({
    required String conversationId,
    required String messageId,
    required String reaction,
  }) async {
    try {
      await _api.patch(
        ApiEndpoints.conversationMessageReaction(conversationId, messageId),
        {'reaction': reaction},
      );
      return const Right(null);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markRead({
    required String conversationId,
  }) async {
    try {
      await _api.post(ApiEndpoints.conversationRead(conversationId));
      return const Right(null);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
