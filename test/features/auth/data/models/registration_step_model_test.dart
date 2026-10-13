import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/auth/data/models/registration_step_model.dart';

void main() {
  group('RegistrationStepModel parsing against gate-closes-api-v2', () {
    test('parses the set-password response', () {
      final model = RegistrationStepModel.fromJson(const {
        'message': 'Password set. Proceed to set gender.',
        'signupStep': 'completed',
      });

      expect(model.message, 'Password set. Proceed to set gender.');
      expect(model.signupStep, 'completed');
      expect(model.isCompleted, isFalse);
    });

    test('parses the set-username-gender completion response', () {
      final model = RegistrationStepModel.fromJson(const {
        'message': 'Username and gender set successfully. Signup completed.',
        'user': {'id': 'u1'},
        'signupStep': 'completed',
        'signupCompleted': true,
      });

      expect(model.isCompleted, isTrue);
      expect(model.signupStep, 'completed');
    });
  });
}
