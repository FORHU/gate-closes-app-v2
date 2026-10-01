import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/emoji_reaction_picker.dart';
import 'package:gate_closes/shared/widgets/glass_card.dart';
import 'package:gate_closes/shared/widgets/waveform_player.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';

/// One Terminal Echo: sender, caption, voice memo, reactions and listens.
/// Used by the feed and by the map's pin card (Expo's `EchoCard`).
///
/// Tapping opens the reply thread. [onReacted] fires after a reaction is
/// sent, for a caller that shows an echo outside the feed's live state.
class EchoCard extends ConsumerWidget {
  const EchoCard({required this.echo, this.onReacted, super.key});

  final TerminalEchoEntity echo;
  final VoidCallback? onReacted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final name = echo.senderUsername ?? 'Unknown traveler';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return InkWell(
      onTap: () => context.push(RouteNames.echoThreadFor(echo.id), extra: echo),
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
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
                  // Expo's AliasAvatar shows the display name in capitals.
                  child: Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
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
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
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
            // Expo's EmojiReactionBar: one chip per reaction in use, yours
            // highlighted, plus a button to add or change your reaction.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final MapEntry(:key, value: count)
                    in _reactionCounts.entries)
                  if (count > 0)
                    _ReactionChip(
                      emoji: kEmojiReactions[key]!,
                      count: count,
                      mine: echo.userReaction == key,
                    ),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => unawaited(_react(context, ref)),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.add_reaction_outlined,
                      size: 18,
                      color: colors.textMuted,
                      semanticLabel: 'React',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.hearing_rounded, size: 14, color: colors.textMuted),
                Text(
                  '${echo.countListens}',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> get _reactionCounts => {
        'like': echo.countReactLike,
        'love': echo.countReactLove,
        'haha': echo.countReactHaha,
        'wow': echo.countReactWow,
        'sad': echo.countReactSad,
        'angry': echo.countReactAngry,
      };

  Future<void> _react(BuildContext context, WidgetRef ref) async {
    final reaction = await EmojiReactionPicker.show(context);
    if (reaction == null) return;
    await ref.read(terminalEchoControllerProvider.notifier).react(
          echoId: echo.id,
          reaction: EchoReactionType.values.byName(reaction),
        );
    onReacted?.call();
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

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.mine,
  });

  final String emoji;
  final int count;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: mine
            ? colors.accent.withValues(alpha: 0.18)
            : colors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mine ? colors.accent : colors.border),
      ),
      child: Text(
        '$emoji $count',
        style: TextStyle(color: colors.textPrimary, fontSize: 12),
      ),
    );
  }
}
