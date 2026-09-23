import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_template/core/config/app_config.dart';
import 'package:flutter_template/core/errors/exceptions.dart';
import 'package:flutter_template/core/services/adapter_config/adapter_config.dart';
import 'package:flutter_template/core/services/cookie_service.dart';
import 'package:flutter_template/core/services/interceptors/auth_interceptor.dart';
import 'package:flutter_template/core/services/storage_service.dart';
import 'package:flutter_template/core/utils/logger.dart';

/// Thin, typed wrapper around [Dio]. Every network call in the app goes through
/// here. Methods return decoded JSON and throw [AppException] subtypes on
/// failure — repositories translate those into `Failure` values.
///
/// Point it at your backend by setting `BASE_URL` (see `.env.*`).
class ApiService {
  ApiService({
    required StorageService storage,
    CookieService? cookieService,
    void Function()? onUnauthenticated,
    Dio? dio,
  }) : client = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.instance.baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 10),
                contentType: Headers.jsonContentType,
              ),
            ) {
    // 0. Enable Web credentials & native platform cookie jar
    configureWebCredentials(client);
    final jar = cookieService?.jar;
    if (jar != null && !kIsWeb) {
      client.interceptors.add(CookieManager(jar));
    }

    // 1. Attach the bearer token and transparently refresh it on a 401.
    client.interceptors.add(
      AuthInterceptor(
        storage,
        baseUrl: client.options.baseUrl,
        cookieService: cookieService,
        onUnauthenticated: onUnauthenticated,
      ),
    );

    // 2. Retry transient failures on unstable networks
    //    (skip 4xx client errors).
    client.interceptors.add(
      RetryInterceptor(
        dio: client,
        logPrint: appLogger.w,
        retryEvaluator: (error, attempt) {
          final status = error.response?.statusCode;
          if (status != null && status >= 400 && status < 500) {
            return false;
          }
          return error.type != DioExceptionType.cancel &&
              error.type != DioExceptionType.badResponse;
        },
        retryDelays: const [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 3),
        ],
      ),
    );

    // 3. Verbose request/response logging (dev only).
    if (AppConfig.instance.enableLogging) {
      client.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }

  /// Exposed so interceptors/tests can configure or replace the client.
  final Dio client;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => client.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => client.post<dynamic>(path, data: body));

  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => client.put<dynamic>(path, data: body));

  Future<dynamic> patch(String path, [Object? body]) =>
      _send(() => client.patch<dynamic>(path, data: body));

  Future<dynamic> delete(String path, [Object? body]) =>
      _send(() => client.delete<dynamic>(path, data: body));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Normalizes Dio's transport-level errors into the app's typed exceptions.
  AppException _mapError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return UnauthorizedException(_messageFrom(e) ?? 'Unauthorized access');
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return ServerException(
          _messageFrom(e) ?? 'Unexpected server error',
          statusCode: status,
        );
    }
  }

  /// Pulls a human-readable message from a `{ "message": "..." }` error body,
  /// falling back to Dio's own message.
  String? _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return e.message;
  }
}
