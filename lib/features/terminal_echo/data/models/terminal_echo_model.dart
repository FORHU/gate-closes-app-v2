import 'package:flutter_template/features/terminal_echo/domain/entities/terminal_echo_entity.dart';

class TerminalEchoModel extends TerminalEchoEntity {
  const TerminalEchoModel({
    required super.id,
    required super.senderId,
    required super.textMessage,
    required super.airportIata,
    required super.createdAt,
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
    super.userReaction,
  });

  factory TerminalEchoModel.fromJson(Map<String, dynamic> json) {
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map)
            ? (json['data'] as Map).cast<String, dynamic>()
            : json;

    final id = (payload['_id'] ?? payload['id'] ?? '').toString();
    final senderId = (payload['senderId'] ?? '').toString();
    final textMessage = (payload['textMessage'] ?? '').toString();
    final airportIata =
        (payload['airportIata'] ?? payload['airportName'] ?? '').toString();

    final createdStr = (payload['createdAt'] ?? '').toString();
    final createdAt = DateTime.tryParse(createdStr) ?? DateTime.now();

    final rawWaves = payload['waveformData'];
    final waveformData = rawWaves is List
        ? rawWaves.map((e) => (e is num) ? e.toDouble() : 0.0).toList()
        : <double>[];

    final rawDuration = payload['audioDuration'];
    final audioDuration = rawDuration is num ? rawDuration.toDouble() : 0.0;

    return TerminalEchoModel(
      id: id,
      senderId: senderId,
      textMessage: textMessage,
      airportIata: airportIata,
      createdAt: createdAt,
      fileUrl: payload['fileUrl'] as String?,
      fileName: payload['fileName'] as String?,
      audioDuration: audioDuration,
      waveformData: waveformData,
      countListens: (payload['countListens'] as num?)?.toInt() ?? 0,
      countReactLike: (payload['countReactLike'] as num?)?.toInt() ?? 0,
      countReactLove: (payload['countReactLove'] as num?)?.toInt() ?? 0,
      countReactHaha: (payload['countReactHaha'] as num?)?.toInt() ?? 0,
      countReactWow: (payload['countReactWow'] as num?)?.toInt() ?? 0,
      countReactSad: (payload['countReactSad'] as num?)?.toInt() ?? 0,
      countReactAngry: (payload['countReactAngry'] as num?)?.toInt() ?? 0,
      senderUsername: payload['senderUsername'] as String?,
      userReaction: payload['userReaction'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'textMessage': textMessage,
        'airportIata': airportIata,
        'createdAt': createdAt.toIso8601String(),
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
        'userReaction': userReaction,
      };
}
