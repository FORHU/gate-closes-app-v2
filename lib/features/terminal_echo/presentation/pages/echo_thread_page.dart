import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/file_upload_service.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_reply_entity.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_thread_controller.dart';
import 'package:gate_closes/shared/widgets/app_state_view.dart';
import 'package:gate_closes/shared/widgets/emoji_reaction_picker.dart';
import 'package:gate_closes/shared/widgets/glass_card.dart';
import 'package:gate_closes/shared/widgets/voice_recorder_composer.dart';
import 'package:gate_closes/shared/widgets/waveform_player.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

class EchoThreadPage extends ConsumerStatefulWidget {
  const EchoThreadPage({
    required this.echo,
    super.key,
  });

  final TerminalEchoEntity echo;

  @override
  ConsumerState<EchoThreadPage> createState() => _EchoThreadPageState();
}

class _EchoThreadPageState extends ConsumerState<EchoThreadPage> {
  final _textController = TextEditingController();
  bool _showVoiceComposer = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      ref
          .read(terminalEchoThreadControllerProvider.notifier)
          .openThread(widget.echo.id),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool _isInsideTargetAirport() {
    final airportState = ref.read(airportControllerProvider);
    if (airportState.airport == null) return false;
    return airportState.airport!.iata.toUpperCase() ==
        widget.echo.airportIata.toUpperCase();
  }

  void _showGeofenceWarning() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) {
          final colors = context.colors;
          return AlertDialog(
            backgroundColor: colors.surface,
            title: Text(
              'Outside Airport Boundary',
              style: TextStyle(color: colors.textPrimary),
            ),
            content: Text(
              'You are currently outside ${widget.echo.airportIata}. '
              'Terminal Echo interactions are geo-restricted to travelers '
              'at this airport.',
              style: TextStyle(color: colors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child:
                    Text('Understood', style: TextStyle(color: colors.accent)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleSendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (!_isInsideTargetAirport()) {
      _showGeofenceWarning();
      return;
    }

    final success = await ref
        .read(terminalEchoThreadControllerProvider.notifier)
        .sendReply(textMessage: text);

    if (success) {
      _textController.clear();
      if (mounted) FocusScope.of(context).unfocus();
    }
  }

  Future<void> _handleSendVoice(
    File file,
    double durationSeconds,
    List<double> waveform,
  ) async {
    if (!_isInsideTargetAirport()) {
      _showGeofenceWarning();
      return;
    }

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
      if (uploaded == null) return;

      final success = await ref
          .read(terminalEchoThreadControllerProvider.notifier)
          .sendReply(
            fileUrl: uploaded.url,
            fileName: uploaded.key,
            textMessage: _textController.text.trim(),
            audioDuration: durationSeconds,
            waveformData: waveform,
          );

      if (success) {
        _textController.clear();
        setState(() {
          _showVoiceComposer = false;
        });
      }
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload voice reply: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final threadState = ref.watch(terminalEchoThreadControllerProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          'Echo — ${widget.echo.airportIata}',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AppSpacing.edgeInsetsMd,
              children: [
                _ParentEchoCard(echo: widget.echo),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Replies (${threadState.replies.length})',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (threadState.isLoading && threadState.replies.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (threadState.error != null &&
                    threadState.replies.isEmpty)
                  AppStateView(
                    kind: AppStateKind.error,
                    title: 'Failed to load replies',
                    message: threadState.error,
                    actionLabel: 'Retry',
                    onAction: () => unawaited(
                      ref
                          .read(
                            terminalEchoThreadControllerProvider.notifier,
                          )
                          .openThread(widget.echo.id),
                    ),
                  )
                else if (threadState.replies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: Text(
                        'No replies yet. Join the conversation!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...threadState.replies.map(
                    (reply) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ReplyTile(
                        echoId: widget.echo.id,
                        reply: reply,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildComposer(colors, threadState),
        ],
      ),
    );
  }

  Widget _buildComposer(
    GateColors colors,
    TerminalEchoThreadState threadState,
  ) {
    if (_showVoiceComposer) {
      return Container(
        color: colors.surface,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Voice Reply',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _showVoiceComposer = false),
                ),
              ],
            ),
            VoiceRecorderComposer(
              onRecorded: _handleSendVoice,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.mic_rounded, color: colors.accent),
              onPressed: () {
                if (!_isInsideTargetAirport()) {
                  _showGeofenceWarning();
                  return;
                }
                setState(() => _showVoiceComposer = true);
              },
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextField(
                controller: _textController,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Add a reply...',
                  hintStyle: TextStyle(color: colors.textMuted),
                  filled: true,
                  fillColor: colors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _handleSendText(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: threadState.isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send_rounded, color: colors.accent),
              onPressed: threadState.isSending ? null : _handleSendText,
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentEchoCard extends ConsumerWidget {
  const _ParentEchoCard({required this.echo});

  final TerminalEchoEntity echo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final name = echo.senderUsername ?? 'Unknown traveler';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.accent.withValues(alpha: 0.18),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      echo.airportIata,
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _timeAgo(echo.createdAt),
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
            ],
          ),
          if (echo.textMessage.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              echo.textMessage,
              style: TextStyle(color: colors.textPrimary, fontSize: 15),
            ),
          ],
          if (echo.isVoiceMemo) ...[
            const SizedBox(height: AppSpacing.sm),
            WaveformPlayer(
              audioUrl: echo.fileUrl!,
              waveformData: echo.waveformData,
              durationSeconds: echo.audioDuration,
              onListenThresholdReached: () => unawaited(
                ref
                    .read(terminalEchoControllerProvider.notifier)
                    .incrementListen(echo.id),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              GestureDetector(
                onTap: () => unawaited(_react(context, ref)),
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 14,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${echo.totalReactions}',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.hearing_rounded, size: 14, color: colors.textMuted),
              const SizedBox(width: 4),
              Text(
                '${echo.countListens}',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _react(BuildContext context, WidgetRef ref) async {
    final reaction = await EmojiReactionPicker.show(context);
    if (reaction == null) return;
    await ref.read(terminalEchoControllerProvider.notifier).react(
          echoId: echo.id,
          reaction: EchoReactionType.values.byName(reaction),
        );
  }

  String _timeAgo(DateTime date) {
    final mins = DateTime.now().difference(date).inMinutes;
    if (mins < 1) return 'now';
    if (mins < 60) return '${mins}m ago';
    final hrs = mins ~/ 60;
    if (hrs < 24) return '${hrs}h ago';
    return '${hrs ~/ 24}d ago';
  }
}

class _ReplyTile extends ConsumerWidget {
  const _ReplyTile({
    required this.echoId,
    required this.reply,
  });

  final String echoId;
  final TerminalEchoReplyEntity reply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final name = reply.senderUsername ?? 'Traveler';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: colors.accent.withValues(alpha: 0.14),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                _timeAgo(reply.createdAt),
                style: TextStyle(color: colors.textMuted, fontSize: 10),
              ),
            ],
          ),
          if (reply.textMessage.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              reply.textMessage,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ],
          if (reply.isVoiceMemo) ...[
            const SizedBox(height: AppSpacing.xs),
            WaveformPlayer(
              audioUrl: reply.fileUrl!,
              waveformData: reply.waveformData,
              durationSeconds: reply.audioDuration,
              onListenThresholdReached: () => unawaited(
                ref
                    .read(
                      terminalEchoThreadControllerProvider.notifier,
                    )
                    .incrementListen(reply.id),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              GestureDetector(
                onTap: () => unawaited(_react(context, ref)),
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 13,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${reply.totalReactions}',
                      style: TextStyle(color: colors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.hearing_rounded, size: 13, color: colors.textMuted),
              const SizedBox(width: 4),
              Text(
                '${reply.countListens}',
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _react(BuildContext context, WidgetRef ref) async {
    final reaction = await EmojiReactionPicker.show(context);
    if (reaction == null) return;
    await ref.read(terminalEchoThreadControllerProvider.notifier).react(
          replyId: reply.id,
          reaction: EchoReactionType.values.byName(reaction),
        );
  }

  String _timeAgo(DateTime date) {
    final mins = DateTime.now().difference(date).inMinutes;
    if (mins < 1) return 'now';
    if (mins < 60) return '${mins}m ago';
    final hrs = mins ~/ 60;
    if (hrs < 24) return '${hrs}h ago';
    return '${hrs ~/ 24}d ago';
  }
}
