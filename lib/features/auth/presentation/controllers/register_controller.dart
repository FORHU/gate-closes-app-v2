import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';

/// The 4 real signup steps on `gate-closes-api` (verified against
/// `user.auth.route.ts`/`user.auth.controller.ts`) — not a single call.
enum RegisterStep { email, otp, password, usernameGender }

class RegisterState extends Equatable {
  const RegisterState({
    this.step = RegisterStep.email,
    this.isLoading = false,
    this.error,
    this.userId,
    this.email = '',
    this.password = '',
  });

  final RegisterStep step;
  final bool isLoading;
  final String? error;
  final String? userId;
  final String email;

  /// Held only in memory, only long enough to auto-login once the wizard
  /// completes — `setUsernameGender`'s response carries no access/refresh
  /// tokens (none of the signup steps do), so completing the wizard doesn't
  /// itself authenticate the user; a real `login` call right after does.
  final String password;

  RegisterState copyWith({
    RegisterStep? step,
    bool? isLoading,
    String? error,
    String? userId,
    String? email,
    String? password,
  }) {
    return RegisterState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      // Intentionally not `error ?? this.error`: passing null clears it.
      error: error,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }

  @override
  List<Object?> get props => [step, isLoading, error, userId, email, password];
}

class RegisterController extends Notifier<RegisterState> {
  @override
  RegisterState build() => const RegisterState();

  Future<bool> submitEmail(String email) async {
    state = state.copyWith(isLoading: true, email: email);
    final result = await ref.read(authRepositoryProvider).registerEmail(email);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (step) {
        // "set_password" means this email already verified a prior attempt
        // — skip straight past OTP instead of re-sending one.
        final nextStep = step.signupStep == 'set_password'
            ? RegisterStep.password
            : RegisterStep.otp;
        state = state.copyWith(
          isLoading: false,
          userId: step.userId,
          step: nextStep,
        );
        return true;
      },
    );
  }

  Future<bool> verifyOtp(String code) async {
    final userId = state.userId;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true);
    final result = await ref.read(authRepositoryProvider).verifyEmail(
          userId,
          code,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, step: RegisterStep.password);
        return true;
      },
    );
  }

  Future<bool> resendOtp() async {
    final userId = state.userId;
    if (userId == null) return false;

    final result = await ref.read(authRepositoryProvider).resendCode(userId);
    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
      (_) => true,
    );
  }

  Future<bool> submitPassword(String password, String confirmPassword) async {
    final userId = state.userId;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true);
    final result = await ref.read(authRepositoryProvider).setPassword(
          userId,
          password,
          confirmPassword,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          // Held only to auto-login after the final step — see field doc.
          password: password,
          step: RegisterStep.usernameGender,
        );
        return true;
      },
    );
  }

  /// Completes signup, then logs in with the credentials just set — none of
  /// the signup steps return tokens, so this is a real second network call,
  /// not a formality.
  Future<bool> submitUsernameGender(String username, String gender) async {
    final userId = state.userId;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true);
    final result = await ref.read(authRepositoryProvider).setUsernameGender(
          userId,
          username,
          gender,
        );

    return result.fold(
      (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) async {
        final loggedIn = await ref
            .read(authControllerProvider.notifier)
            .login(state.email, state.password);
        state = state.copyWith(isLoading: false);
        return loggedIn;
      },
    );
  }
}

final registerControllerProvider =
    NotifierProvider<RegisterController, RegisterState>(
  RegisterController.new,
);
