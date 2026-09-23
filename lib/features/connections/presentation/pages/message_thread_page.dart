import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_template/features/connections/domain/entities/connection_entity.dart';
import 'package:flutter_template/features/connections/domain/entities/conversation_message_entity.dart';
import 'package:flutter_template/features/connections/presentation/controllers/message_thread_controller.dart';
import 'package:flutter_template/shared/widgets/app_state_view.dart';
import 'package:flutter_template/shared/widgets/emoji_reaction_picker.dart';
import 'package:flutter_template/theme/tokens/colors.dart';
import 'package:flutter_template/theme/tokens/radius.dart';
import 'package:flutter_template/theme/tokens/spacing.dart';

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
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

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
    _textController.dispose();
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

  Future<void> _send() async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    final ok =
        await ref.read(messageThreadControllerProvider.notifier).sendText(text);
    if (ok) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
          _Composer(controller: _textController, onSend: _send, colors: colors),
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
        message: 'No messages yet — send the first one.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: AppSpacing.edgeInsetsMd,
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        return _MessageBubble(
          message: message,
          isMine: message.isMine(currentUserId),
          accent: accent,
          onReact: (reaction) => ref
              .read(messageThreadControllerProvider.notifier)
              .react(messageId: message.id, reaction: reaction),
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.colors,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final GateColors colors;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(color: colors.textMuted),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.brPill,
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.brPill,
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.brPill,
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
              color: colors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.accent,
    required this.onReact,
  });

  final ConversationMessageEntity message;
  final bool isMine;
  final Color accent;
  final ValueChanged<String> onReact;

  Future<void> _showReactionPicker(BuildContext context) async {
    final reaction = await EmojiReactionPicker.show(context);
    if (reaction != null) onReact(reaction);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bubbleColor =
        isMine ? accent.withValues(alpha: 0.18) : colors.surface;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          GestureDetector(
            onLongPress: () => _showReactionPicker(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(18),
                  border: isMine
                      ? Border.all(color: accent.withValues(alpha: 0.4))
                      : Border.all(color: colors.border),
                ),
                child: Text(
                  message.textMessage.isNotEmpty
                      ? message.textMessage
                      : (message.isVoiceMemo
                          ? '🎤 Voice memo'
                          : '(empty message)'),
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
            ),
          ),
          if (message.reactions.isNotEmpty) ...[
            const SizedBox(height: 2),
            Wrap(
              spacing: 4,
              children: [
                for (final entry in message.reactions.entries)
                  if (entry.value > 0)
                    Text(
                      '${kEmojiReactions[entry.key] ?? entry.key} '
                      '${entry.value}',
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
