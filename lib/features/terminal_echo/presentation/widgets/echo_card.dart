import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/listen_counts.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:gate_closes/features/terminal_echo/presentation/widgets/reaction_chips.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/emoji_reaction_picker.dart';
import 'package:gate_closes/shared/widgets/glass_card.dart';
import 'package:gate_closes/shared/widgets/user_avatar.dart';
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

    return InkWell(
      onTap: () => context.push(RouteNames.echoThreadFor(echo.id), extra: echo),
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  name: name,
                  picture: echo.senderPicture,
                  userId: echo.senderId,
                  radius: 16,
                  tint: colors.accentText,
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
            ReactionChips(
              counts: echo.reactionCounts,
              mine: {if (echo.userReaction case final r?) r},
              onReact: () => unawaited(_react(context, ref)),
              trailing: [
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.hearing_rounded, size: 14, color: colors.textMuted),
                Text(
                  '${watchListens(ref, echo.id, echo.countListens)}',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
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
