import 'package:flutter_template/features/connections/domain/entities/connection_entity.dart';

class ConnectionModel extends ConnectionEntity {
  const ConnectionModel({
    required super.id,
    required super.type,
    required super.participantIds,
    required super.dmKey,
    super.otherUserId,
    super.otherUserName,
    super.otherUserAvatar,
    super.lastEventText,
    super.lastEventAt,
    super.hasUnread = false,
  });

  /// Parses a conversation document as returned by
  /// `ConversationSvc.shapeConversationForUser` — see
  /// `gate-closes-api/src/services/conversation.service.ts`.
  factory ConnectionModel.fromJson(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'] ?? '').toString();
    final type = ConnectionType.fromApiKey(
      (json['type'] ?? 'parallel_soul').toString(),
    );

    final participantsRaw = json['participants'];
    final participantIds = participantsRaw is List
        ? participantsRaw.map((p) {
            if (p is Map) return (p['_id'] ?? p['id'] ?? '').toString();
            return p.toString();
          }).toList()
        : <String>[];

    final otherUser = json['otherUser'];
    final otherUserId = otherUser is Map
        ? (otherUser['_id'] ?? otherUser['id'])?.toString()
        : null;
    final otherUserName = otherUser is Map
        ? (otherUser['name'] ?? otherUser['username'])?.toString()
        : null;

    final lastEventAtStr = json['lastEventAt']?.toString();

    return ConnectionModel(
      id: id,
      type: type,
      participantIds: participantIds,
      dmKey: (json['dmKey'] ?? '').toString(),
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      lastEventText: json['lastEventText'] as String?,
      lastEventAt:
          lastEventAtStr != null ? DateTime.tryParse(lastEventAtStr) : null,
      hasUnread: json['hasUnread'] as bool? ?? false,
    );
  }
}
