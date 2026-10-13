import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/profile/data/models/profile_model.dart';

void main() {
  test('reads GET /auth/me: the account is nested under user', () {
    final profile = ProfileModel.fromJson(const {
      'user': {
        'id': 'u1',
        'email': 'developer@example.com',
        'username': 'test_developer',
      },
      'permissions': ['airports:simulate'],
      'requiresProfileCompletion': false,
    });

    expect(profile.id, 'u1');
    expect(profile.name, 'test_developer');
    expect(profile.email, 'developer@example.com');
  });

  test("prefers the username over Better Auth's empty name", () {
    final profile = ProfileModel.fromJson(const {
      'user': {'id': 'u1', 'name': '', 'username': 'ava_morgan'},
    });

    expect(profile.name, 'ava_morgan');
  });
}
