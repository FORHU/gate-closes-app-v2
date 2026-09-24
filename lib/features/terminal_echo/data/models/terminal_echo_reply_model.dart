import 'package:flutter_template/features/terminal_echo/domain/entities/terminal_echo_reply_entity.dart';

class TerminalEchoReplyModel extends TerminalEchoReplyEntity {
  const TerminalEchoReplyModel({
    required super.id,
    required super.terminalEchoId,
    required super.senderId,
    required super.createdAt,
    super.textMessage = '',
    super.fileUrl,
    super.fileName,
    super.audioDuration = 0,
    super.waveformData = const [],
    super.countListens = 0,
    super.countReactLike = 0,
    super.countReactLove = 0,
    super.countReactHaha = 0,
    super.countReactWow = 0,
    super.countReactSad = 0,
    super.countReactAngry = 0,
    super.senderUsername,
    super.senderGender,
    super.currentUserReactions = const [],
  });

  factory TerminalEchoReplyModel.fromJson(Map<String, dynamic> json) {
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map)
            ? (json['data'] as Map).cast<String, dynamic>()
            : json;

    final id = (payload['_id'] ?? payload['id'] ?? '').toString();
    final terminalEchoId = (payload['terminalEchoId'] ?? '').toString();
    final senderId = (payload['senderId'] ?? '').toString();
    final textMessage = (payload['textMessage'] ?? '').toString();

    final createdStr = (payload['createdAt'] ?? '').toString();
    final createdAt = DateTime.tryParse(createdStr) ?? DateTime.now();

    // Attached file information via `file` object if present
    final fileObj = payload['file'] is Map ? payload['file'] as Map : null;
    final fileUrl = (fileObj?['fileUrl'] ?? payload['fileUrl']) as String?;
    final fileName = (fileObj?['fileName'] ?? payload['fileName']) as String?;

    final fileMeta =
        fileObj?['metaData'] is Map ? fileObj!['metaData'] as Map : null;
    final rawWaves = fileMeta?['waveformData'] ?? payload['waveformData'];
    final waveformData = rawWaves is List
        ? rawWaves.map((e) => (e is num) ? e.toDouble() : 0.0).toList()
        : <double>[];

    final rawDuration = fileMeta?['audioDuration'] ?? payload['audioDuration'];
    final audioDuration = rawDuration is num ? rawDuration.toDouble() : 0.0;

    // Sender details via joined user object
    final userObj = payload['user'] is Map ? payload['user'] as Map : null;
    final senderUsername =
        (userObj?['username'] ?? payload['senderUsername']) as String?;
    final senderGender =
        (userObj?['gender'] ?? payload['senderGender']) as String?;

    final rawReactions = payload['currentUserReactions'];
    final currentUserReactions = rawReactions is List
        ? rawReactions.map((e) => e.toString()).toList()
        : <String>[];

    return TerminalEchoReplyModel(
      id: id,
      terminalEchoId: terminalEchoId,
      senderId: senderId,
      createdAt: createdAt,
      textMessage: textMessage,
      fileUrl: fileUrl,
      fileName: fileName,
      audioDuration: audioDuration,
      waveformData: waveformData,
      countListens: (payload['countListens'] as num?)?.toInt() ?? 0,
      countReactLike: (payload['countReactLike'] as num?)?.toInt() ?? 0,
      countReactLove: (payload['countReactLove'] as num?)?.toInt() ?? 0,
      countReactHaha: (payload['countReactHaha'] as num?)?.toInt() ?? 0,
      countReactWow: (payload['countReactWow'] as num?)?.toInt() ?? 0,
      countReactSad: (payload['countReactSad'] as num?)?.toInt() ?? 0,
      countReactAngry: (payload['countReactAngry'] as num?)?.toInt() ?? 0,
      senderUsername: senderUsername,
      senderGender: senderGender,
      currentUserReactions: currentUserReactions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'terminalEchoId': terminalEchoId,
        'senderId': senderId,
        'createdAt': createdAt.toIso8601String(),
        'textMessage': textMessage,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'audioDuration': audioDuration,
        'waveformData': waveformData,
        'countListens': countListens,
        'countReactLike': countReactLike,
        'countReactLove': countReactLove,
        'countReactHaha': countReactHaha,
        'countReactWow': countReactWow,
        'countReactSad': countReactSad,
        'countReactAngry': countReactAngry,
        'senderUsername': senderUsername,
        'senderGender': senderGender,
        'currentUserReactions': currentUserReactions,
      };
}
