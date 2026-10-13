import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel parsing against gate-closes-api-v2', () {
    test('parses the sign-in response (Better Auth: token + user)', () {
      const json = {
        'redirect': false,
        'token': 'session-token',
        'user': {
          'id': '3f0c9a52-6f43-4c1b-9d1e-2a7b4c5d6e7f',
          'email': 'ava.morgan@example.com',
          'username': 'ava99.01',
          'gender': 'Female',
          'signupCompleted': true,
          'isCompleteProfile': true,
          'image': null,
        },
      };

      final model = UserModel.fromJson(json);

      expect(model.id, '3f0c9a52-6f43-4c1b-9d1e-2a7b4c5d6e7f');
      expect(model.email, 'ava.morgan@example.com');
      expect(model.name, 'ava99.01');
      expect(model.gender, 'Female');
      expect(model.token, 'session-token');
      expect(model.signupCompleted, isTrue);
      expect(model.isCompleteProfile, isTrue);
    });

    test('parses GET /auth/me (user + permissions, no token)', () {
      final model = UserModel.fromJson(const {
        'user': {
          'id': 'u1',
          'email': 'dev@example.com',
          'username': 'dev01',
          'picture': 'https://example.com/avatar.png',
          'signupCompleted': true,
          'isCompleteProfile': false,
        },
        'permissions': ['premium', 'airports:simulate'],
        'requiresProfileCompletion': true,
      });

      expect(model.id, 'u1');
      expect(model.token, isEmpty);
      expect(model.picture, 'https://example.com/avatar.png');
      expect(model.isCompleteProfile, isFalse);
      expect(model.permissions, ['premium', 'airports:simulate']);
    });

    test('serializes and deserializes UserModel accurately', () {
      const model = UserModel(
        id: 'user123',
        email: 'user@example.com',
        name: 'user01.23',
        token: 'token123',
        gender: 'Male',
        picture: 'https://example.com/pic.jpg',
      );

      final json = model.toJson();
      expect(json['id'], 'user123');
      expect(json['gender'], 'Male');
      expect(json['picture'], 'https://example.com/pic.jpg');

      final reconstructed = UserModel.fromJson({'user': json});

      expect(reconstructed.id, model.id);
      expect(reconstructed.email, model.email);
      expect(reconstructed.name, model.name);
      expect(reconstructed.gender, model.gender);
    });

    test('toJson never includes the token (cached in plaintext prefs)', () {
      const model = UserModel(
        id: 'user123',
        email: 'user@example.com',
        name: 'user01.23',
        token: 'token123',
      );

      expect(model.toJson().containsKey('token'), isFalse);
    });
  });
}
