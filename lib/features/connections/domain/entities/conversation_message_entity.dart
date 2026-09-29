import 'package:equatable/equatable.dart';

/// A single message within a conversation thread, matching the shape
/// returned by `ConversationSvc.listMessages` / `sendMessage` in
/// `gate-closes-api` — includes the resolved attachment (`file`) and
/// `sender` (username + gender only, no avatar) joined server-side.
class ConversationMessageEntity extends Equatable {
  const ConversationMessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.textMessage = '',
    this.fileUrl,
    this.fileName,
    this.audioDuration = 0,
    this.waveformData = const [],
    this.reactions = const {},
    this.currentUserReactions = const [],
    this.senderUsername,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String textMessage;

  /// Null unless this message carries a voice-memo/attachment.
  final String? fileUrl;
  final String? fileName;
  final double audioDuration;
  final List<double> waveformData;

  /// Emoji -> total count, e.g. `{"like": 3, "love": 1}`.
  final Map<String, int> reactions;

  /// Which emoji(s) the *current* user has reacted with, so the UI can
  /// highlight them without a separate lookup.
  final List<String> currentUserReactions;

  final String? senderUsername;
  final DateTime? createdAt;

  bool get isVoiceMemo => fileUrl != null;

  bool isMine(String currentUserId) => senderId == currentUserId;

  ConversationMessageEntity copyWith({
    Map<String, int>? reactions,
    List<String>? currentUserReactions,
  }) {
    return ConversationMessageEntity(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      textMessage: textMessage,
      fileUrl: fileUrl,
      fileName: fileName,
      audioDuration: audioDuration,
      waveformData: waveformData,
      reactions: reactions ?? this.reactions,
      currentUserReactions: currentUserReactions ?? this.currentUserReactions,
      senderUsername: senderUsername,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderId,
        textMessage,
        fileUrl,
        fileName,
        audioDuration,
        waveformData,
        reactions,
        currentUserReactions,
        senderUsername,
        createdAt,
      ];
}
