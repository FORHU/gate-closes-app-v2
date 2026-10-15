import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';

/// The preset avatars a traveler can pick, by id, with their names. Art is
/// `assets/avatars/<id>.svg`, shipped as the PNG `tool/render_map_badges.dart`
/// renders from it. The API's edit-profile accepts exactly these ids.
const Map<String, String> presetAvatars = {
  'traveler-m': 'Male Traveler',
  'traveler-f': 'Female Traveler',
  'chick': 'Chick Pilot',
  'gator': 'Gator',
  'jet': 'Jet',
  'penguin': 'Penguin Crew',
  'fox': 'Fox Backpacker',
  'cat': 'Sleepy Cat',
  'koala': 'Koala',
  'suitcase': 'Suitcase Buddy',
  'balloon': 'Balloon',
};

const _prefix = 'avatar:';

/// The user `picture` value for preset [id].
String presetAvatarPicture(String id) => '$_prefix$id';

/// The preset id stored in [picture], or null when it isn't one (no picture,
/// or another kind of picture such as a Google photo URL).
String? presetAvatarId(String? picture) {
  if (picture == null || !picture.startsWith(_prefix)) return null;
  final id = picture.substring(_prefix.length);
  return presetAvatars.containsKey(id) ? id : null;
}

/// A traveler's avatar: their preset avatar, or a letter circle.
///
/// Pass [userId] for someone else's content (an echo, a reply): when it's the
/// signed-in user, their current picture wins over the one the content was
/// loaded with, so a change shows everywhere at once without a reload.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    required this.name,
    required this.radius,
    this.picture,
    this.userId,
    this.tint,
    super.key,
  });

  final String name;
  final String? picture;
  final double radius;
  final String? userId;

  /// The letter circle's color: a soft [tint] disc with a [tint] letter.
  /// Without it, the solid accent circle of the profile pages.
  final Color? tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = userId == null
        ? null
        : ref.watch(authControllerProvider.select((s) => s.user));
    final shown = me != null && me.id == userId ? me.picture : picture;
    final id = presetAvatarId(shown);
    if (id != null) {
      return ClipOval(
        child: Image.asset(
          'assets/avatars/$id.png',
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          semanticLabel: presetAvatars[id],
        ),
      );
    }
    final colors = context.colors;
    final tint = this.tint;
    return CircleAvatar(
      radius: radius,
      backgroundColor: tint?.withValues(alpha: 0.18) ?? colors.accent,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.bold,
          color: tint ?? colors.accentOn,
        ),
      ),
    );
  }
}
