import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/config/app_config.dart';
import 'package:flutter_template/core/services/storage_service.dart';
import 'package:flutter_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_template/features/terminal_echo/data/models/terminal_echo_reply_model.dart';
import 'package:flutter_template/features/terminal_echo/data/repositories/terminal_echo_reply_repository_impl.dart';
import 'package:flutter_template/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:flutter_template/features/terminal_echo/domain/entities/terminal_echo_reply_entity.dart';
import 'package:flutter_template/features/terminal_echo/domain/repositories/terminal_echo_reply_repository.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

final terminalEchoReplyRepositoryProvider =
    Provider<TerminalEchoReplyRepository>((ref) {
  return TerminalEchoReplyRepositoryImpl(ref.watch(apiServiceProvider));
});

class TerminalEchoThreadState extends Equatable {
  const TerminalEchoThreadState({
    this.isLoading = false,
    this.isSending = false,
    this.replies = const [],
    this.echoId,
    this.error,
  });

  final bool isLoading;
  final bool isSending;
  final List<TerminalEchoReplyEntity> replies;
  final String? echoId;
  final String? error;

  TerminalEchoThreadState copyWith({
    bool? isLoading,
    bool? isSending,
    List<TerminalEchoReplyEntity>? replies,
    String? echoId,
    String? error,
  }) {
    return TerminalEchoThreadState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      replies: replies ?? this.replies,
      echoId: echoId ?? this.echoId,
      error: error,
    );
  }

  @override
  List<Object?> get props => [isLoading, isSending, replies, echoId, error];
}

class TerminalEchoThreadController extends Notifier<TerminalEchoThreadState> {
  io.Socket? _socket;
  String? _echoId;

  @override
  TerminalEchoThreadState build() {
    ref.onDispose(_disconnectSocket);
    return const TerminalEchoThreadState();
  }

  Future<void> openThread(String echoId) async {
    _echoId = echoId;
    state = state.copyWith(isLoading: true, echoId: echoId);
    final repo = ref.read(terminalEchoReplyRepositoryProvider);
    final result = await repo.getReplies(echoId);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (replies) {
        state = state.copyWith(
          isLoading: false,
          replies: replies,
        );
        _initSocket(echoId);
      },
    );
  }

  void _initSocket(String echoId) {
    final token = ref.read(storageServiceProvider).readUserModel()?.token;
    _disconnectSocket();

    final baseUrl = AppConfig.instance.baseUrl;
    final uri = Uri.parse(baseUrl);
    final socketUrl = '${uri.scheme}://${uri.host}:${uri.port}/terminal-echo';

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setExtraHeaders(
            token != null ? {'Authorization': 'Bearer $token'} : {},
          )
          .setAuth({
            if (token != null) 'accessToken': token,
          })
          .build(),
    );

    _socket!.onConnect((_) {
      _socket!.emit('terminal_echo:join_map', {'room': 'thread:$echoId'});
    });

    _socket!.on('terminal_echo_reply:created', (data) {
      if (data is Map && data['reply'] is Map) {
        final newReply = TerminalEchoReplyModel.fromJson(
          (data['reply'] as Map).cast<String, dynamic>(),
        );
        if (!state.replies.any((r) => r.id == newReply.id)) {
          state = state.copyWith(replies: [newReply, ...state.replies]);
        }
      }
    });

    _socket!.on('terminal_echo_reply:reaction_updated', (data) {
      if (data is Map) {
        final replyId = data['replyId']?.toString();
        final reactionKey = data['reactionKey']?.toString();
        final action = data['action']?.toString();
        if (replyId == null || reactionKey == null || action == null) return;

        final isInc = action == 'increment';
        state = state.copyWith(
          replies: state.replies.map((reply) {
            if (reply.id != replyId) return reply;

            var countLike = reply.countReactLike;
            var countLove = reply.countReactLove;
            var countHaha = reply.countReactHaha;
            var countWow = reply.countReactWow;
            var countSad = reply.countReactSad;
            var countAngry = reply.countReactAngry;

            final delta = isInc ? 1 : -1;
            switch (reactionKey) {
              case 'like':
                countLike = (countLike + delta).clamp(0, 999999);
              case 'love':
                countLove = (countLove + delta).clamp(0, 999999);
              case 'haha':
                countHaha = (countHaha + delta).clamp(0, 999999);
              case 'wow':
                countWow = (countWow + delta).clamp(0, 999999);
              case 'sad':
                countSad = (countSad + delta).clamp(0, 999999);
              case 'angry':
                countAngry = (countAngry + delta).clamp(0, 999999);
            }

            return reply.copyWith(
              countReactLike: countLike,
              countReactLove: countLove,
              countReactHaha: countHaha,
              countReactWow: countWow,
              countReactSad: countSad,
              countReactAngry: countAngry,
            );
          }).toList(),
        );
      }
    });
  }

  void _disconnectSocket() {
    if (_socket != null) {
      if (_echoId != null) {
        _socket!.emit('terminal_echo:leave_map', {'room': 'thread:$_echoId'});
      }
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  Future<bool> sendReply({
    String? fileUrl,
    String? fileName,
    String? textMessage,
    double audioDuration = 0,
    List<double> waveformData = const [],
  }) async {
    final echoId = _echoId;
    if (echoId == null) return false;

    state = state.copyWith(isSending: true);
    final repo = ref.read(terminalEchoReplyRepositoryProvider);

    final result = await repo.createReply(
      terminalEchoId: echoId,
      fileUrl: fileUrl,
      fileName: fileName,
      textMessage: textMessage,
      audioDuration: audioDuration,
      waveformData: waveformData,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isSending: false, error: failure.message);
        return false;
      },
      (reply) {
        if (!state.replies.any((r) => r.id == reply.id)) {
          state = state.copyWith(
            isSending: false,
            replies: [reply, ...state.replies],
          );
        } else {
          state = state.copyWith(isSending: false);
        }
        return true;
      },
    );
  }

  Future<void> react({
    required String replyId,
    required EchoReactionType reaction,
  }) async {
    final target = state.replies.firstWhere((r) => r.id == replyId);
    final isCurrentlyReacted = target.hasReacted(reaction.name);

    // Optimistic local update
    final delta = isCurrentlyReacted ? -1 : 1;
    final updatedReactions = List<String>.from(target.currentUserReactions);
    if (isCurrentlyReacted) {
      updatedReactions.remove(reaction.name);
    } else {
      updatedReactions.add(reaction.name);
    }

    var countLike = target.countReactLike;
    var countLove = target.countReactLove;
    var countHaha = target.countReactHaha;
    var countWow = target.countReactWow;
    var countSad = target.countReactSad;
    var countAngry = target.countReactAngry;

    switch (reaction) {
      case EchoReactionType.like:
        countLike = (countLike + delta).clamp(0, 999999);
      case EchoReactionType.love:
        countLove = (countLove + delta).clamp(0, 999999);
      case EchoReactionType.haha:
        countHaha = (countHaha + delta).clamp(0, 999999);
      case EchoReactionType.wow:
        countWow = (countWow + delta).clamp(0, 999999);
      case EchoReactionType.sad:
        countSad = (countSad + delta).clamp(0, 999999);
      case EchoReactionType.angry:
        countAngry = (countAngry + delta).clamp(0, 999999);
    }

    state = state.copyWith(
      replies: state.replies.map((r) {
        if (r.id != replyId) return r;
        return r.copyWith(
          countReactLike: countLike,
          countReactLove: countLove,
          countReactHaha: countHaha,
          countReactWow: countWow,
          countReactSad: countSad,
          countReactAngry: countAngry,
          currentUserReactions: updatedReactions,
        );
      }).toList(),
    );

    final repo = ref.read(terminalEchoReplyRepositoryProvider);
    await repo.updateReaction(
      replyId: replyId,
      reaction: reaction,
      isCurrentlyReacted: isCurrentlyReacted,
    );
  }

  Future<void> incrementListen(String replyId) async {
    final repo = ref.read(terminalEchoReplyRepositoryProvider);
    await repo.incrementListen(replyId);
  }
}

final terminalEchoThreadControllerProvider =
    NotifierProvider<TerminalEchoThreadController, TerminalEchoThreadState>(
  TerminalEchoThreadController.new,
);
