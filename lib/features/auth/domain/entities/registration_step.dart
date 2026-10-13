import 'package:equatable/equatable.dart';

/// Result of one step in the signup wizard: `{message, signupStep?,
/// signupCompleted?}`. The wizard is keyed by email; from the code step on,
/// the session token (saved by the repository) identifies the user.
class RegistrationStep extends Equatable {
  const RegistrationStep({
    required this.message,
    this.signupStep,
    this.isCompleted = false,
  });

  final String message;
  final String? signupStep;
  final bool isCompleted;

  @override
  List<Object?> get props => [message, signupStep, isCompleted];
}
