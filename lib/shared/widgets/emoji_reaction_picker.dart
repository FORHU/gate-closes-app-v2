import 'package:flutter/material.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/theme/tokens/radius.dart';
import 'package:flutter_template/theme/tokens/spacing.dart';

/// The 6 backend-supported reaction keys, shared by Terminal Echo
/// (`terminal.echo.controller.ts`) and Messaging (`ConversationCtrl.
/// updateReaction`) — both use the exact same Joi enum.
const kEmojiReactions = {
  'like': '👍',
  'love': '❤️',
  'haha': '😂',
  'wow': '😮',
  'sad': '😢',
  'angry': '😠',
};

/// A row of the 6 reaction emojis in a bottom sheet. Shared by Terminal
/// Echo's reaction bar and Messaging's long-press reaction picker.
class EmojiReactionPicker extends StatelessWidget {
  const EmojiReactionPicker({required this.onSelect, super.key});

  final ValueChanged<String> onSelect;

  /// Shows the picker as a bottom sheet and returns the tapped reaction key
  /// (or null if dismissed without a selection).
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => EmojiReactionPicker(
        onSelect: (reaction) => Navigator.of(context).pop(reaction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.md,
        children: [
          for (final entry in kEmojiReactions.entries)
            InkWell(
              borderRadius: AppRadius.brPill,
              onTap: () => onSelect(entry.key),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                ),
                child: Text(entry.value, style: const TextStyle(fontSize: 22)),
              ),
            ),
        ],
      ),
    );
  }
}
