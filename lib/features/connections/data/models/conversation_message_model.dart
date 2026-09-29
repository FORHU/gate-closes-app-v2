import 'package:gate_closes/features/connections/domain/entities/conversation_message_entity.dart';

class ConversationMessageModel extends ConversationMessageEntity {
  const ConversationMessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    super.textMessage,
    super.fileUrl,
    super.fileName,
    super.audioDuration,
    super.waveformData,
    super.reactions,
    super.currentUserReactions,
    super.senderUsername,
    super.createdAt,
  });

  /// Parses the aggregation result from
  /// `ConversationMessageRepo.listByConversationId` /
  /// `ConversationSvc.sendMessage` — see
  /// `gate-closes-api/src/repositories/conversation.message.repository.ts`.
  factory ConversationMessageModel.fromJson(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'] ?? '').toString();
    final conversationId = (json['conversationId'] ?? '').toString();
    final senderIdRaw = json['senderId'];
    final senderId = senderIdRaw is Map
        ? (senderIdRaw['_id'] ?? '').toString()
        : (senderIdRaw ?? '').toString();

    final file = json['file'];
    final metaData = file is Map ? file['metaData'] : null;
    final waveformRaw = metaData is Map ? metaData['waveformData'] : null;

    final sender = json['sender'];

    final reactionsRaw = json['reactions'];
    final reactions = reactionsRaw is Map
        ? reactionsRaw.map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt()),
          )
        : <String, int>{};

    final currentUserReactionsRaw = json['currentUserReactions'];
    final currentUserReactions = currentUserReactionsRaw is List
        ? currentUserReactionsRaw.map((e) => e.toString()).toList()
        : <String>[];

    final createdAtStr = json['createdAt']?.toString();

    return ConversationMessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      textMessage: (json['textMessage'] ?? '').toString(),
      fileUrl: file is Map ? file['fileUrl'] as String? : null,
      fileName: file is Map ? file['fileName'] as String? : null,
      audioDuration: metaData is Map
          ? ((metaData['audioDuration'] as num?)?.toDouble() ?? 0)
          : 0,
      waveformData: waveformRaw is List
          ? waveformRaw.map((e) => (e as num).toDouble()).toList()
          : const [],
      reactions: reactions,
      currentUserReactions: currentUserReactions,
      senderUsername: sender is Map ? sender['username'] as String? : null,
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) : null,
    );
  }
}
