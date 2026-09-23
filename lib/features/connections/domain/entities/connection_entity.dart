import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// The 3 domain connection paradigms.
enum ConnectionType {
  parallelSoul,
  destinationThread,
  batonTouch;

  /// Per-type accent, ported from `gate-closes-app`'s
  /// `constants/{parallelSoul,destinationThread,batonTouch}Theme.ts`. Kept
  /// feature-local rather than a global semantic token since it's a
  /// content-category color, not a theme color.
  Color get accent {
    switch (this) {
      case ConnectionType.parallelSoul:
        return const Color(0xFF50D6FF);
      case ConnectionType.destinationThread:
        return const Color(0xFFFFB457);
      case ConnectionType.batonTouch:
        return const Color(0xFFCF3573);
    }
  }

  String get label {
    switch (this) {
      case ConnectionType.parallelSoul:
        return 'Parallel Soul';
      case ConnectionType.destinationThread:
        return 'Destination Thread';
      case ConnectionType.batonTouch:
        return 'Baton Touch';
    }
  }

  String toApiKey() {
    switch (this) {
      case ConnectionType.parallelSoul:
        return 'parallel_soul';
      case ConnectionType.destinationThread:
        return 'destination_thread';
      case ConnectionType.batonTouch:
        return 'baton_touch';
    }
  }

  static ConnectionType fromApiKey(String key) {
    switch (key) {
      case 'destination_thread':
        return ConnectionType.destinationThread;
      case 'baton_touch':
        return ConnectionType.batonTouch;
      case 'parallel_soul':
      default:
        return ConnectionType.parallelSoul;
    }
  }
}

/// Domain entity representing a conversation thread, matching the unified
/// `Conversation` shape returned by `gate-closes-api`
/// (`shapeConversationForUser` in `conversation.service.ts`).
class ConnectionEntity extends Equatable {
  const ConnectionEntity({
    required this.id,
    required this.type,
    required this.participantIds,
    required this.dmKey,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
    this.lastEventText,
    this.lastEventAt,
    this.hasUnread = false,
  });

  final String id;
  final ConnectionType type;
  final List<String> participantIds;
  final String dmKey;

  /// From `otherUser._id`. Null only if the backend couldn't resolve a
  /// counterpart (shouldn't happen for a DM, but the API allows for it).
  final String? otherUserId;

  /// From `otherUser.username`.
  final String? otherUserName;

  /// Always null today — the backend's participant projection only returns
  /// `{ _id, username, gender }`, no avatar/photo field exists yet. Kept
  /// nullable so the UI already falls back to an initials avatar and picks
  /// up a real photo for free if the backend adds one later.
  final String? otherUserAvatar;

  /// Pre-formatted preview text for the last event (message sent, reacted,
  /// etc.) — from `lastEventText`.
  final String? lastEventText;
  final DateTime? lastEventAt;

  /// From `hasUnread` (boolean) — the backend does not expose a numeric
  /// unread count for conversations, only whether there's unread activity.
  final bool hasUnread;

  ConnectionEntity copyWith({
    String? id,
    ConnectionType? type,
    List<String>? participantIds,
    String? dmKey,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
    String? lastEventText,
    DateTime? lastEventAt,
    bool? hasUnread,
  }) {
    return ConnectionEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      participantIds: participantIds ?? this.participantIds,
      dmKey: dmKey ?? this.dmKey,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      lastEventText: lastEventText ?? this.lastEventText,
      lastEventAt: lastEventAt ?? this.lastEventAt,
      hasUnread: hasUnread ?? this.hasUnread,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        participantIds,
        dmKey,
        otherUserId,
        otherUserName,
        otherUserAvatar,
        lastEventText,
        lastEventAt,
        hasUnread,
      ];
}
