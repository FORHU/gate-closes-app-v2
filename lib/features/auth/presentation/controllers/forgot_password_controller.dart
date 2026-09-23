import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/features/auth/presentation/controllers/auth_controller.dart';

/// The 3 interactive steps of the forgot-password wizard (verified against
/// `user.auth.route.ts`): request code → verify code → set new password.
/// Successful completion logs the user in with the new password — like
/// signup, none of these steps return access/refresh tokens.
enum ForgotPasswordStep { email, otp, newPassword }

class ForgotPasswordState extends Equatable {
  const ForgotPasswordState({
    this.step = ForgotPasswordStep.email,
    this.isLoading = false,
    this.error,
    this.userId,
    this.email = '',
    this.isDone = false,
  });

  final ForgotPasswordStep step;
  final bool isLoading;
  final String? error;
  final String? userId;
  final String email;
  final bool isDone;

  ForgotPasswordState copyWith({
    ForgotPasswordStep? step,
    bool? isLoading,
    String? error,
    String? userId,
    String? email,
    bool? isDone,
  }) {
    return ForgotPasswordState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      // Intentionally not `error ?? this.error`: passing null clears it.
      error: error,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      isDone: isDone ?? this.isDone,
    );
  }

  @override
  List<Object?> get props => [step, isLoading, error, userId, email, isDone];
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
      (step) {
        state = state.copyWith(
          isLoading: false,
          userId: step.userId,
          step: ForgotPasswordStep.otp,
        );
        return true;
      },
    );
  }

  Future<bool> resendCode() async {
    final userId = state.userId;
    if (userId == null) return false;

    final result = await ref.read(authRepositoryProvider).resendResetCode(
          userId,
        );
    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
      (_) => true,
    );
  }

  Future<bool> verifyCode(String code) async {
    final userId = state.userId;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true);
    final result =
        await ref.read(authRepositoryProvider).verifyResetCode(userId, code);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          step: ForgotPasswordStep.newPassword,
        );
        return true;
      },
    );
  }

  /// Sets the new password, then logs in with it — `resetPassword`'s
  /// response carries no tokens, so this is a real second network call.
  Future<bool> submitNewPassword(
    String password,
    String confirmPassword,
  ) async {
    final userId = state.userId;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true);
    final result = await ref
        .read(authRepositoryProvider)
        .resetPassword(userId, password, confirmPassword);

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
