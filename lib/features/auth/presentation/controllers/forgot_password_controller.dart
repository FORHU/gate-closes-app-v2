import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';

/// The 3 interactive steps of the forgot-password wizard on
/// gate-closes-api-v2: request code → check code → set new password with
/// that code. Checking doesn't use the code up; 3 wrong tries do.
/// Successful completion logs the user in with the new password.
enum ForgotPasswordStep { email, otp, newPassword }

class ForgotPasswordState extends Equatable {
  const ForgotPasswordState({
    this.step = ForgotPasswordStep.email,
    this.isLoading = false,
    this.error,
    this.email = '',
    this.code = '',
    this.isDone = false,
  });

  final ForgotPasswordStep step;
  final bool isLoading;
  final String? error;
  final String email;

  /// The checked code, sent again with the new password.
  final String code;
  final bool isDone;

  ForgotPasswordState copyWith({
    ForgotPasswordStep? step,
    bool? isLoading,
    String? error,
    String? email,
    String? code,
    bool? isDone,
  }) {
    return ForgotPasswordState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      // Intentionally not `error ?? this.error`: passing null clears it.
      error: error,
      email: email ?? this.email,
      code: code ?? this.code,
      isDone: isDone ?? this.isDone,
    );
  }

  @override
  List<Object?> get props => [step, isLoading, error, email, code, isDone];
}

class ForgotPasswordController extends Notifier<ForgotPasswordState> {
  @override
  ForgotPasswordState build() => const ForgotPasswordState();

  Future<bool> requestCode(String email) async {
    state = state.copyWith(isLoading: true, email: email);
    final result = await ref.read(authRepositoryProvider).forgotPassword(email);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          step: ForgotPasswordStep.otp,
        );
        return true;
      },
    );
  }

  Future<bool> resendCode() async {
    if (state.email.isEmpty) return false;

    final result =
        await ref.read(authRepositoryProvider).resendResetCode(state.email);
    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
      (_) => true,
    );
  }

  Future<bool> verifyCode(String code) async {
    if (state.email.isEmpty) return false;

    state = state.copyWith(isLoading: true);
    final result = await ref
        .read(authRepositoryProvider)
        .verifyResetCode(state.email, code);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          code: code,
          step: ForgotPasswordStep.newPassword,
        );
        return true;
      },
    );
  }

  /// Sets the new password, then logs in with it — the reset response
  /// carries no session, so this is a real second network call. The API
  /// takes one password, so the match is checked here.
  Future<bool> submitNewPassword(
    String password,
    String confirmPassword,
  ) async {
    if (state.email.isEmpty || state.code.isEmpty) return false;
    if (password != confirmPassword) {
      state = state.copyWith(error: 'Passwords do not match.');
      return false;
    }

    state = state.copyWith(isLoading: true);
    final result = await ref
        .read(authRepositoryProvider)
        .resetPassword(state.email, state.code, password);

    return result.fold(
      (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) async {
        final loggedIn = await ref
            .read(authControllerProvider.notifier)
            .login(state.email, password);
        state = state.copyWith(isLoading: false, isDone: loggedIn);
        return loggedIn;
      },
    );
  }
}

final forgotPasswordControllerProvider =
    NotifierProvider<ForgotPasswordController, ForgotPasswordState>(
  ForgotPasswordController.new,
);
