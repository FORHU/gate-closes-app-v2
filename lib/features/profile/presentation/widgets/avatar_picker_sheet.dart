import 'package:flutter/material.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/shared/widgets/buttons.dart';
import 'package:gate_closes/shared/widgets/user_avatar.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// "Choose your avatar": the letter avatar plus every preset, the chosen one
/// previewed with the username, and Use Avatar to confirm.
class AvatarPickerSheet extends StatefulWidget {
  const AvatarPickerSheet({required this.name, this.current, super.key});

  final String name;

  /// The user's current `picture`.
  final String? current;

  /// The chosen `picture` (`value` null for the letter avatar), or null when
  /// dismissed without choosing.
  static Future<({String? value})?> show(
    BuildContext context, {
    required String name,
    String? current,
  }) {
    return showModalBottomSheet<({String? value})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarPickerSheet(name: name, current: current),
    );
  }

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  /// Null is the letter avatar; anything that isn't a preset counts as it.
  late final String? _current =
      presetAvatarId(widget.current) == null ? null : widget.current;
  late String? _selected = _current;

  static final List<String?> _options = [
    null,
    ...presetAvatars.keys.map(presetAvatarPicture),
  ];

  String _label(String? picture) =>
      presetAvatars[presetAvatarId(picture)] ?? 'Initial';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: colors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Choose your avatar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Balances Cancel so the title stays centered.
                  const SizedBox(width: 72),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    name: widget.name,
                    picture: _selected,
                    radius: 29,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _label(_selected),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '@${widget.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.8,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                children: [for (final option in _options) _tile(option)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: PrimaryButton(
                label: 'Use Avatar',
                // Nothing to save until the choice differs from the current.
                onPressed: _selected == _current
                    ? null
                    : () => Navigator.of(context).pop((value: _selected)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String? option) {
    final colors = context.colors;
    final selected = option == _selected;
    return Semantics(
      button: true,
      selected: selected,
      label: _label(option),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selected = option),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? colors.accent : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: UserAvatar(
                    name: widget.name,
                    picture: option,
                    radius: 32,
                  ),
                ),
                if (selected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.surfaceElevated,
                          width: 2.5,
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: colors.accentOn,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _label(option),
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? colors.accentText : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
