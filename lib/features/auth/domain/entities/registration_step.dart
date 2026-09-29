import 'package:equatable/equatable.dart';

/// Result of one step in the signup or forgot-password wizard.
///
/// Every step on `gate-closes-api` responds with `{message, userId?,
/// signupStep?, signupCompleted?}` — none of them return access/refresh
/// tokens, including the final step. The caller logs in separately with the
/// password once `isCompleted` is true.
class RegistrationStep extends Equatable {
  const RegistrationStep({
    required this.userId,
    required this.message,
    this.signupStep,
    this.isCompleted = false,
  });

  final String userId;
  final String message;
  final String? signupStep;
  final bool isCompleted;

  @override
  List<Object?> get props => [userId, message, signupStep, isCompleted];
}
