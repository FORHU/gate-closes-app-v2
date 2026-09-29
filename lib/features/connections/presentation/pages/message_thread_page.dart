import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/file_upload_service.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/connections/domain/entities/connection_entity.dart';
import 'package:gate_closes/features/connections/domain/entities/conversation_message_entity.dart';
import 'package:gate_closes/features/connections/presentation/controllers/message_thread_controller.dart';
import 'package:gate_closes/shared/widgets/app_state_view.dart';
import 'package:gate_closes/shared/widgets/emoji_reaction_picker.dart';
import 'package:gate_closes/shared/widgets/voice_recorder_composer.dart';
import 'package:gate_closes/shared/widgets/waveform_player.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// 1-on-1 thread for a single connection. Realtime sync is `/conversations`
/// socket-backed (see [MessageThreadController]); marking read only updates
/// this user's own state — the backend has no live read-receipt broadcast
/// for the other participant, so no "seen" indicator is shown for them.
class MessageThreadPage extends ConsumerStatefulWidget {
  const MessageThreadPage({required this.connection, super.key});

  final ConnectionEntity connection;

  @override
  ConsumerState<MessageThreadPage> createState() => _MessageThreadPageState();
}

class _MessageThreadPageState extends ConsumerState<MessageThreadPage> {
  final _scrollController = ScrollController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      ref
          .read(messageThreadControllerProvider.notifier)
          .openThread(widget.connection.id),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    unawaited(
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  Future<void> _handleSendVoice(
    File file,
    double durationSeconds,
    List<double> waveform,
  ) async {
    setState(() => _isUploading = true);
    try {
      final uploadService = ref.read(fileUploadServiceProvider);
      final uploadRes = await uploadService.uploadAudio(file);

      final uploaded = uploadRes.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure.message)),
            );
          }
          return null;
        },
        (up) => up,
      );

      if (uploaded == null) {
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      final success =
          await ref.read(messageThreadControllerProvider.notifier).sendVoice(
                fileUrl: uploaded.url,
                audioDuration: durationSeconds * 1000,
                waveformData: waveform,
                fileName: uploaded.key,
              );

      if (mounted) {
        setState(() => _isUploading = false);
      }

      if (success) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = widget.connection.type.accent;
    final currentUserId = ref.watch(authControllerProvider).user?.id ?? '';

    ref.listen(messageThreadControllerProvider, (previous, next) {
      if ((previous?.messages.length ?? 0) < next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    final state = ref.watch(messageThreadControllerProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: accent.withValues(alpha: 0.18),
              child: Text(
                (widget.connection.otherUserName?.isNotEmpty ?? false)
                    ? widget.connection.otherUserName![0].toUpperCase()
                    : '?',
                style: TextStyle(color: accent, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              widget.connection.otherUserName ?? 'Unknown traveler',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(state, currentUserId, colors, accent)),
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Sending voice note...',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ],
              ),
            ),
          VoiceRecorderComposer(
            isInline: true,
            accentColor: accent,
            onRecorded: _handleSendVoice,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    MessageThreadState state,
    String currentUserId,
    GateColors colors,
    Color accent,
  ) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.messages.isEmpty) {
      return AppStateView(
        kind: AppStateKind.error,
        title: 'Could not load this conversation',
        message: state.error,
        actionLabel: 'Retry',
        onAction: () => ref
            .read(messageThreadControllerProvider.notifier)
            .openThread(widget.connection.id),
      );
    }

    if (state.messages.isEmpty) {
      return const AppStateView(
        kind: AppStateKind.empty,
        title: 'Say hello',
        message: 'No messages yet — send a voice note to start.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: AppSpacing.edgeInsetsMd,
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        final isMine = message.isMine(currentUserId);

        // Grouping: index is 0..length-1 (oldest to newest)
        final older = index > 0 ? state.messages[index - 1] : null;
        final newer = index < state.messages.length - 1
            ? state.messages[index + 1]
            : null;

        final startsGroup = older == null || older.senderId != message.senderId;
        final endsGroup = newer == null || newer.senderId != message.senderId;

        return _MessageBubble(
          message: message,
          isMine: isMine,
          accent: accent,
          startsGroup: startsGroup,
          endsGroup: endsGroup,
          onReact: (reaction) => ref
              .read(messageThreadControllerProvider.notifier)
              .react(messageId: message.id, reaction: reaction),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.accent,
    required this.startsGroup,
    required this.endsGroup,
    required this.onReact,
  });

  final ConversationMessageEntity message;
  final bool isMine;
  final Color accent;
  final bool startsGroup;
  final bool endsGroup;
  final ValueChanged<String> onReact;

  Future<void> _showReactionPicker(BuildContext context) async {
    final reaction = await EmojiReactionPicker.show(context);
    if (reaction != null) onReact(reaction);
  }

  BorderRadius _bubbleBorderRadius() {
    const rBig = 18.0;
    const rSmall = 4.0;

    if (isMine) {
      if (startsGroup && endsGroup) {
        return BorderRadius.circular(rBig);
      }
      if (startsGroup && !endsGroup) {
        return const BorderRadius.only(
          topLeft: Radius.circular(rBig),
          topRight: Radius.circular(rBig),
          bottomRight: Radius.circular(rBig),
          bottomLeft: Radius.circular(rSmall),
        );
      }
      if (!startsGroup && !endsGroup) {
        return const BorderRadius.only(
          topLeft: Radius.circular(rSmall),
          bottomLeft: Radius.circular(rSmall),
          topRight: Radius.circular(rBig),
          bottomRight: Radius.circular(rBig),
        );
      }
      return const BorderRadius.only(
        topLeft: Radius.circular(rSmall),
        bottomLeft: Radius.circular(rBig),
        topRight: Radius.circular(rBig),
        bottomRight: Radius.circular(rBig),
      );
    } else {
      if (startsGroup && endsGroup) {
        return BorderRadius.circular(rBig);
      }
      if (startsGroup && !endsGroup) {
        return const BorderRadius.only(
          topLeft: Radius.circular(rBig),
          bottomLeft: Radius.circular(rBig),
          topRight: Radius.circular(rBig),
          bottomRight: Radius.circular(rSmall),
        );
      }
      if (!startsGroup && !endsGroup) {
        return const BorderRadius.only(
          topLeft: Radius.circular(rBig),
          bottomLeft: Radius.circular(rBig),
          topRight: Radius.circular(rSmall),
          bottomRight: Radius.circular(rSmall),
        );
      }
      return const BorderRadius.only(
        topLeft: Radius.circular(rBig),
        bottomLeft: Radius.circular(rBig),
        topRight: Radius.circular(rSmall),
        bottomRight: Radius.circular(rBig),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bubbleColor =
        isMine ? accent.withValues(alpha: 0.18) : colors.surface;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: EdgeInsets.only(
        top: startsGroup ? 6 : 2,
        bottom: endsGroup ? 6 : 2,
      ),
      child: Column(
        crossAxisAlignment: align,
        children: [
          GestureDetector(
            onLongPress: () => _showReactionPicker(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: _bubbleBorderRadius(),
                  border: isMine
                      ? Border.all(color: accent.withValues(alpha: 0.4))
                      : Border.all(color: colors.border),
                ),
                child: message.isVoiceMemo
                    ? WaveformPlayer(
                        audioUrl: message.fileUrl!,
                        waveformData: message.waveformData,
                        durationSeconds: message.audioDuration > 0
                            ? message.audioDuration / 1000
                            : 0,
                      )
                    : Text(
                        message.textMessage.isNotEmpty
                            ? message.textMessage
                            : '(empty voice memo)',
                        style: TextStyle(color: colors.textPrimary),
                      ),
              ),
            ),
          ),
          if (message.reactions.isNotEmpty) ...[
            const SizedBox(height: 3),
            Wrap(
              spacing: 4,
              children: [
                for (final entry in message.reactions.entries)
                  if (entry.value > 0)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onReact(entry.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                message.currentUserReactions.contains(entry.key)
                                    ? accent
                                    : colors.border,
                          ),
                        ),
                        child: Text(
                          '${kEmojiReactions[entry.key] ?? entry.key} '
                          '${entry.value}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
