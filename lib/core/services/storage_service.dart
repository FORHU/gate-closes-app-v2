import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gate_closes/features/auth/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two-tier local storage:
/// * [SharedPreferences] for non-sensitive values (flags, prefs, cached user).
/// * [FlutterSecureStorage] for secrets (auth tokens) — encrypted at rest.
class StorageService {
  StorageService(this._prefs, {FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userModelKey = 'cached_user_model';
  static const String _onboardingKey = 'onboarding_seen';

  // --- Plain key/value ---
  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<void> remove(String key) => _prefs.remove(key);

  // --- Secure (access token) ---
  Future<void> saveToken(String token) =>
      _secure.write(key: _tokenKey, value: token);
  Future<String?> readToken() => _secure.read(key: _tokenKey);

  // --- Secure (refresh token) ---
  Future<void> saveRefreshToken(String token) =>
      _secure.write(key: _refreshTokenKey, value: token);
  Future<String?> readRefreshToken() => _secure.read(key: _refreshTokenKey);

  // --- Cached user model (SharedPreferences, for instant cold start) ---
  Future<void> saveUserModel(UserModel user) =>
      _prefs.setString(_userModelKey, jsonEncode(user.toJson()));

  UserModel? readUserModel() {
    final raw = _prefs.getString(_userModelKey);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } on Object catch (_) {
      return null;
    }
  }

  // --- Onboarding flag ---
  bool get onboardingSeen => _prefs.getBool(_onboardingKey) ?? false;
  Future<void> setOnboardingSeen() => _prefs.setBool(_onboardingKey, true);

  /// Clears the whole authenticated session (tokens + cached user).
  Future<void> clearSession() async {
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _refreshTokenKey);
    await _prefs.remove(_userModelKey);
  }
}

/// Overridden in `main()` with the resolved instance — see [ProviderScope].
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(ref.watch(sharedPreferencesProvider)),
);
