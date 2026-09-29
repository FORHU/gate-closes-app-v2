import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/auth/data/models/registration_step_model.dart';

void main() {
  group('RegistrationStepModel parsing against gate-closes-api contracts', () {
    test('parses registerEmail response (userId present)', () {
      final model = RegistrationStepModel.fromJson(const {
        'message': 'OTP sent to email.',
        'userId': 'u1',
        'signupStep': 'otp_pending',
      });

      expect(model.userId, 'u1');
      expect(model.message, 'OTP sent to email.');
      expect(model.signupStep, 'otp_pending');
      expect(model.isCompleted, isFalse);
    });

    test(
        'falls back to the caller-supplied userId when the response omits '
        'it (verifyEmail/setPassword/etc. never echo userId back)', () {
      final model = RegistrationStepModel.fromJson(
        const {
          'message': 'Email verified. Proceed to set password.',
          'signupStep': 'set_password',
        },
        fallbackUserId: 'u1',
      );

      expect(model.userId, 'u1');
      expect(model.signupStep, 'set_password');
    });

    test('parses setUsernameGender completion response', () {
      final model = RegistrationStepModel.fromJson(
        const {
          'message': 'Username and gender set successfully. Signup completed.',
          'signupStep': 'completed',
          'signupCompleted': true,
        },
        fallbackUserId: 'u1',
      );

      expect(model.isCompleted, isTrue);
      expect(model.signupStep, 'completed');
    });
  });
}
