import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';

/// The 4 signup steps on gate-closes-api-v2 (its docs/AUTH.md). The code
/// step signs the user in; the last two steps run on that session.
enum RegisterStep { email, otp, password, usernameGender }

class RegisterState extends Equatable {
  const RegisterState({
    this.step = RegisterStep.email,
    this.isLoading = false,
    this.error,
    this.email = '',
  });

  final RegisterStep step;
  final bool isLoading;
  final String? error;
  final String email;

  RegisterState copyWith({
    RegisterStep? step,
    bool? isLoading,
    String? error,
    String? email,
  }) {
    return RegisterState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      // Intentionally not `error ?? this.error`: passing null clears it.
      error: error,
      email: email ?? this.email,
    );
  }

  @override
  List<Object?> get props => [step, isLoading, error, email];
}

class RegisterController extends Notifier<RegisterState> {
  @override
  RegisterState build() => const RegisterState();

  /// A new Google account is already signed up and signed in; only the
  /// last step (username and gender) is left.
  void startProfileCompletion() {
    state = const RegisterState(step: RegisterStep.usernameGender);
  }

  Future<bool> submitEmail(String email) async {
    state = state.copyWith(isLoading: true, email: email);
    final result = await ref.read(authRepositoryProvider).registerEmail(email);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, step: RegisterStep.otp);
        return true;
      },
    );
  }

  Future<bool> verifyOtp(String code) async {
    if (state.email.isEmpty) return false;

    state = state.copyWith(isLoading: true);
    final result = await ref.read(authRepositoryProvider).verifyEmail(
          state.email,
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
    if (state.email.isEmpty) return false;

    final result =
        await ref.read(authRepositoryProvider).resendCode(state.email);
    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
      (_) => true,
    );
  }

  Future<bool> submitPassword(String password, String confirmPassword) async {
    state = state.copyWith(isLoading: true);
    final result = await ref.read(authRepositoryProvider).setPassword(
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
          step: RegisterStep.usernameGender,
        );
        return true;
      },
    );
  }

  /// Completes signup. The session from the code step is already signed in,
  /// so loading the user is all that's left.
  Future<bool> submitUsernameGender(String username, String gender) async {
    state = state.copyWith(isLoading: true);
    final result = await ref.read(authRepositoryProvider).setUsernameGender(
          username,
          gender,
        );

    return result.fold(
      (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) async {
        await ref.read(authControllerProvider.notifier).refreshAuth();
        final signedIn = ref.read(authControllerProvider).isAuthenticated;
        state = state.copyWith(
          isLoading: false,
          error: signedIn
              ? null
              : 'Signed up, but could not sign in. '
                  'Please log in.',
        );
        return signedIn;
      },
    );
  }
}

final registerControllerProvider =
    NotifierProvider<RegisterController, RegisterState>(
  RegisterController.new,
);
