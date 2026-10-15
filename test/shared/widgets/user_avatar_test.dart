import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/auth/domain/entities/user_entity.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/shared/widgets/user_avatar.dart';
import 'package:gate_closes/theme/light_theme.dart';

/// Signed in as `me`, who has since picked [picture].
class _SignedIn extends AuthController {
  _SignedIn({this.picture});

  final String? picture;

  @override
  AuthState build() => AuthState(
        user: UserEntity(
          id: 'me',
          email: 'me@example.com',
          name: 'gate_wanderer',
          picture: picture,
        ),
      );
}

void main() {
  Future<void> pump(WidgetTester tester, Widget avatar, {String? myPicture}) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _SignedIn(picture: myPicture),
            ),
          ],
          child: MaterialApp(theme: LightTheme.build(), home: avatar),
        ),
      );

  testWidgets('a preset picture shows its avatar image', (tester) async {
    await pump(
      tester,
      const UserAvatar(
        name: 'gate_wanderer',
        picture: 'avatar:chick',
        radius: 40,
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('G'), findsNothing);
  });

  testWidgets('anything else falls back to the initial', (tester) async {
    for (final picture in [
      null,
      'https://lh3.googleusercontent.com/a/photo',
      'avatar:dragon',
    ]) {
      await pump(
        tester,
        UserAvatar(name: 'gate_wanderer', picture: picture, radius: 40),
      );
      expect(find.text('G'), findsOneWidget, reason: '$picture');
      expect(find.byType(Image), findsNothing, reason: '$picture');
    }
  });

  testWidgets("the signed-in user's own content shows their current avatar",
      (tester) async {
    // Loaded before the change: no picture on the echo itself.
    const mine = UserAvatar(name: 'gate_wanderer', userId: 'me', radius: 16);
    await pump(tester, mine, myPicture: 'avatar:chick');
    expect(find.byType(Image), findsOneWidget);

    // Someone else's echo keeps the picture it came with.
    const theirs =
        UserAvatar(name: 'gate_wanderer', userId: 'other', radius: 16);
    await pump(tester, theirs, myPicture: 'avatar:chick');
    expect(find.byType(Image), findsNothing);
  });

  test('every preset round-trips through its picture value', () {
    for (final id in presetAvatars.keys) {
      expect(presetAvatarId(presetAvatarPicture(id)), id);
    }
  });
}
