import 'package:flutter/material.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/shared/widgets/emoji_reaction_picker.dart';

/// Expo's EmojiReactionBar: one chip per reaction in use, the viewer's own
/// ([mine]) highlighted, plus a button to add or change a reaction. Shared
/// by the echo card and the thread page so every screen shows reactions
/// alike.
class ReactionChips extends StatelessWidget {
  const ReactionChips({
    required this.counts,
    required this.onReact,
    this.mine = const {},
    this.trailing = const [],
    super.key,
  });

  /// Count per reaction key (`like`, `love`, ...), as in [kEmojiReactions].
  final Map<String, int> counts;

  /// The viewer's own reaction keys.
  final Set<String> mine;
  final VoidCallback onReact;

  /// Shown after the react button (the listen count).
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final MapEntry(:key, value: count) in counts.entries)
          if (count > 0)
            _ReactionChip(
              emoji: kEmojiReactions[key]!,
              count: count,
              mine: mine.contains(key),
            ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onReact,
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
        ...trailing,
      ],
    );
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
    // Light: a soft grey pill, so it doesn't vanish white-on-white.
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: mine
            ? colors.accent.withValues(alpha: 0.18)
            : light
                ? colors.backgroundCanvas
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
