import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/auth/data/models/registration_step_model.dart';
import 'package:gate_closes/features/auth/data/models/user_model.dart';

/// Talks to the remote API. Knows nothing about storage or UI.
///
/// The signup and forgot-password flows are real multi-step wizards on
/// `gate-closes-api` (verified against `user.auth.controller.ts`) — neither
/// is a single POST, and neither returns tokens directly. Both end by
/// handing back a `userId` the next step must include, and the caller
/// (`RegisterController`/`ForgotPasswordController`) logs in separately
/// with the password once the wizard completes.
abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);

  // --- Signup wizard ---
  Future<RegistrationStepModel> registerEmail(String email);
  Future<RegistrationStepModel> verifyEmail(String userId, String code);
  Future<void> resendCode(String userId);
  Future<RegistrationStepModel> setPassword(
    String userId,
    String password,
    String confirmPassword,
  );
  Future<RegistrationStepModel> setUsernameGender(
    String userId,
    String username,
    String gender,
  );

  // --- Forgot-password wizard ---
  Future<RegistrationStepModel> forgotPassword(String email);
  Future<void> resendResetCode(String userId);
  Future<RegistrationStepModel> verifyResetCode(String userId, String code);
  Future<RegistrationStepModel> resetPassword(
    String userId,
    String password,
    String confirmPassword,
  );

  Future<void> logout(String? refreshToken);
  Future<UserModel> checkAuth(String token);
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

  @override
  Future<UserModel> login(String email, String password) async {
    final data = await _api.post(ApiEndpoints.login, {
      'email': email,
      'password': password,
    });
    return UserModel.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<RegistrationStepModel> registerEmail(String email) async {
    final data = await _api.post(ApiEndpoints.registerEmail, {
      'email': email,
    });
    return RegistrationStepModel.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<RegistrationStepModel> verifyEmail(String userId, String code) async {
    final data = await _api.post(ApiEndpoints.verifyEmail, {
      'userId': userId,
      'code': code,
    });
    return RegistrationStepModel.fromJson(
      (data as Map).cast<String, dynamic>(),
      fallbackUserId: userId,
    );
  }

  @override
  Future<void> resendCode(String userId) async {
    await _api.post(ApiEndpoints.resendCode, {'userId': userId});
  }

  @override
  Future<RegistrationStepModel> setPassword(
    String userId,
    String password,
    String confirmPassword,
  ) async {
    final data = await _api.post(ApiEndpoints.setPassword, {
      'userId': userId,
      'password': password,
      'confirmPassword': confirmPassword,
    });
    return RegistrationStepModel.fromJson(
      (data as Map).cast<String, dynamic>(),
      fallbackUserId: userId,
    );
  }

  @override
  Future<RegistrationStepModel> setUsernameGender(
    String userId,
    String username,
    String gender,
  ) async {
    final data = await _api.post(ApiEndpoints.setUsernameGender, {
      'userId': userId,
      'username': username,
      'gender': gender,
    });
    return RegistrationStepModel.fromJson(
      (data as Map).cast<String, dynamic>(),
      fallbackUserId: userId,
    );
  }

  @override
  Future<RegistrationStepModel> forgotPassword(String email) async {
    final data = await _api.post(ApiEndpoints.forgotPassword, {
      'email': email,
    });
    return RegistrationStepModel.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<void> resendResetCode(String userId) async {
    await _api.post(ApiEndpoints.resendResetCode, {'userId': userId});
  }

  @override
  Future<RegistrationStepModel> verifyResetCode(
    String userId,
    String code,
  ) async {
    final data = await _api.post(ApiEndpoints.verifyResetCode, {
      'userId': userId,
      'code': code,
    });
    return RegistrationStepModel.fromJson(
      (data as Map).cast<String, dynamic>(),
      fallbackUserId: userId,
    );
  }

  @override
  Future<RegistrationStepModel> resetPassword(
    String userId,
    String password,
    String confirmPassword,
  ) async {
    final data = await _api.post(ApiEndpoints.resetPassword, {
      'userId': userId,
      'password': password,
      'confirmPassword': confirmPassword,
    });
    return RegistrationStepModel.fromJson(
      (data as Map).cast<String, dynamic>(),
      fallbackUserId: userId,
    );
  }

  @override
  Future<void> logout(String? refreshToken) async {
    final payload = <String, dynamic>{};
    if (refreshToken != null) payload['refreshToken'] = refreshToken;

    await _api.post(ApiEndpoints.logout, payload);
  }

  @override
  Future<UserModel> checkAuth(String token) async {
    final data = await _api.get(ApiEndpoints.me);
    return UserModel.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<UserModel> editProfile({String? username, String? gender}) async {
    final payload = <String, dynamic>{};
    if (username != null && username.isNotEmpty) payload['username'] = username;
    if (gender != null && gender.isNotEmpty) payload['gender'] = gender;

    final data = await _api.patch(ApiEndpoints.editProfile, payload);
    return UserModel.fromJson((data as Map).cast<String, dynamic>());
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
