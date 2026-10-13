import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/auth/data/models/registration_step_model.dart';
import 'package:gate_closes/features/auth/data/models/user_model.dart';

/// Talks to the remote API. Knows nothing about storage or UI.
///
/// gate-closes-api-v2 runs auth on Better Auth (its docs/AUTH.md). Both
/// wizards are keyed by email:
/// * signup: send a code → the code signs the user in (session token) →
///   set password → set username and gender, all with that session;
/// * forgot password: send a code → check it → reset with code and password,
///   then sign in with the new password.
abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);

  // --- Signup wizard ---
  /// Sends the signup code, or a new one. A finished account gets 400
  /// "Email already registered.".
  Future<void> sendSignupCode(String email);

  /// Signs in with the code: the session token and the user's signup step.
  Future<({String token, String? signupStep})> verifyEmail(
    String email,
    String code,
  );
  Future<RegistrationStepModel> setPassword(
    String password,
    String confirmPassword,
  );
  Future<RegistrationStepModel> setUsernameGender(
    String username,
    String gender,
  );

  // --- Forgot-password wizard ---
  Future<void> sendResetCode(String email);
  Future<void> checkResetCode(String email, String code);
  Future<void> resetPassword(String email, String code, String password);

  Future<void> logout();
  Future<UserModel> checkAuth();
  Future<UserModel> editProfile({String? username, String? gender});
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._api);

  final ApiService _api;

  Map<String, dynamic> _map(Object? data) =>
      (data is Map) ? data.cast<String, dynamic>() : <String, dynamic>{};

  @override
  Future<UserModel> login(String email, String password) async {
    final data = await _api.post(ApiEndpoints.login, {
      'email': email,
      'password': password,
    });
    return UserModel.fromJson(_map(data));
  }

  @override
  Future<void> sendSignupCode(String email) async {
    await _api.post(ApiEndpoints.sendOtp, {'email': email, 'type': 'sign-in'});
  }

  @override
  Future<({String token, String? signupStep})> verifyEmail(
    String email,
    String code,
  ) async {
    final json = _map(
      await _api.post(ApiEndpoints.signInWithOtp, {
        'email': email,
        'otp': code,
      }),
    );
    return (
      token: (json['token'] ?? '').toString(),
      signupStep: _map(json['user'])['signupStep'] as String?,
    );
  }

  @override
  Future<RegistrationStepModel> setPassword(
    String password,
    String confirmPassword,
  ) async {
    final data = await _api.post(ApiEndpoints.setPassword, {
      'password': password,
      'confirmPassword': confirmPassword,
    });
    return RegistrationStepModel.fromJson(_map(data));
  }

  @override
  Future<RegistrationStepModel> setUsernameGender(
    String username,
    String gender,
  ) async {
    final data = await _api.post(ApiEndpoints.setUsernameGender, {
      'username': username,
      'gender': gender,
    });
    return RegistrationStepModel.fromJson(_map(data));
  }

  @override
  Future<void> sendResetCode(String email) async {
    await _api.post(ApiEndpoints.sendOtp, {
      'email': email,
      'type': 'forget-password',
    });
  }

  @override
  Future<void> checkResetCode(String email, String code) async {
    await _api.post(ApiEndpoints.checkOtp, {
      'email': email,
      'type': 'forget-password',
      'otp': code,
    });
  }

  @override
  Future<void> resetPassword(String email, String code, String password) async {
    await _api.post(ApiEndpoints.resetPassword, {
      'email': email,
      'otp': code,
      'password': password,
    });
  }

  @override
  Future<void> logout() async {
    await _api.post(ApiEndpoints.logout, <String, dynamic>{});
  }

  @override
  Future<UserModel> checkAuth() async {
    final data = await _api.get(ApiEndpoints.me);
    return UserModel.fromJson(_map(data));
  }

  @override
  Future<UserModel> editProfile({String? username, String? gender}) async {
    final payload = <String, dynamic>{};
    if (username != null && username.isNotEmpty) payload['username'] = username;
    if (gender != null && gender.isNotEmpty) payload['gender'] = gender;

    final data = await _api.patch(ApiEndpoints.editProfile, payload);
    return UserModel.fromJson(_map(data));
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _api.post(ApiEndpoints.changePassword, {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
  }
}
