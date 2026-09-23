import 'package:flutter_template/features/auth/domain/entities/registration_step.dart';

class RegistrationStepModel extends RegistrationStep {
  const RegistrationStepModel({
    required super.userId,
    required super.message,
    super.signupStep,
    super.isCompleted,
  });

  /// Parses the `{message, userId?, signupStep?, signupCompleted?}` shape
  /// every signup/forgot-password wizard step returns. Only `registerEmail`
  /// and `forgotPassword` echo back `userId` — every later step needs it
  /// supplied by the caller (`RegisterController`/`ForgotPasswordController`
  /// hold it from step 1), not read from each response.
  factory RegistrationStepModel.fromJson(
    Map<String, dynamic> json, {
    String? fallbackUserId,
  }) {
    return RegistrationStepModel(
      userId: (json['userId'] ?? fallbackUserId ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      signupStep: json['signupStep'] as String?,
      isCompleted: json['signupCompleted'] as bool? ?? false,
    );
  }
}
