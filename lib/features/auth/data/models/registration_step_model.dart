import 'package:gate_closes/features/auth/domain/entities/registration_step.dart';

class RegistrationStepModel extends RegistrationStep {
  const RegistrationStepModel({
    required super.message,
    super.signupStep,
    super.isCompleted,
  });

  /// Parses `{message, signupStep?, signupCompleted?}`, the shape of
  /// set-password and set-username-gender.
  factory RegistrationStepModel.fromJson(Map<String, dynamic> json) {
    return RegistrationStepModel(
      message: (json['message'] ?? '').toString(),
      signupStep: json['signupStep'] as String?,
      isCompleted: json['signupCompleted'] as bool? ?? false,
    );
  }
}
