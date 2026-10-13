import 'package:dio/dio.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/services/cookie_service.dart';
import 'package:gate_closes/core/services/storage_service.dart';

/// Attaches the session token to outgoing requests. Sessions slide on the
/// server and there is no refresh token, so a 401 means the session is over:
/// the local session is cleared and the router falls back to the login flow.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(
    this._storage, {
    this.cookieService,
    this.onUnauthenticated,
  });

  final StorageService _storage;
  final CookieService? cookieService;
  final void Function()? onUnauthenticated;

  /// Endpoints whose 401 is a wrong password or code, not an ended session.
  static const Set<String> _signInPaths = {
    ApiEndpoints.login,
    ApiEndpoints.signInWithOtp,
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_signInPaths.contains(options.path)) {
      final token = await _storage.readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final sentToken = err.requestOptions.headers.containsKey('Authorization');
    if (err.response?.statusCode == 401 &&
        sentToken &&
        !_signInPaths.contains(err.requestOptions.path)) {
      await _storage.clearSession();
      await cookieService?.clearCookies();
      onUnauthenticated?.call();
    }
    handler.next(err);
  }
}
