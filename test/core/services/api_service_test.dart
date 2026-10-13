import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/config/app_config.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockStorageService extends Mock implements StorageService {}

/// A Dio adapter that returns a canned HTTP response, so tests exercise the
/// real ApiService pipeline (interceptors + error mapping) with no network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final Object body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

ApiService _apiReturning({
  required int status,
  required Object body,
  MockStorageService? storage,
  String? token,
  void Function()? onUnauthenticated,
}) {
  final store = storage ?? MockStorageService();
  when(store.readToken).thenAnswer((_) async => token);
  when(store.clearSession).thenAnswer((_) async {});

  final dio = Dio()
    ..httpClientAdapter = _StubAdapter(statusCode: status, body: body);
  return ApiService(
    storage: store,
    dio: dio,
    onUnauthenticated: onUnauthenticated,
  );
}

void main() {
  setUpAll(() {
    // prod config => no mock interceptor, no verbose logging.
    AppConfig.instance = const AppConfig.prod();
  });

  group('ApiService error mapping', () {
    test('returns decoded body on 200', () async {
      final api = _apiReturning(status: 200, body: {'ok': true});
      final data = await api.get('/data');
      expect((data as Map)['ok'], isTrue);
    });

    test('throws UnauthorizedException on 401', () async {
      final api = _apiReturning(status: 401, body: {'message': 'nope'});
      await expectLater(
        api.get('/data'),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            'nope',
          ),
        ),
      );
    });

    test('throws ServerException (not Unauthorized) on 403', () async {
      final api = _apiReturning(status: 403, body: {'message': 'forbidden'});
      await expectLater(
        api.get('/data'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.message, 'message', 'forbidden'),
        ),
      );
    });

    test('throws ServerException on a 4xx (non-auth) response', () async {
      final api = _apiReturning(status: 422, body: {'message': 'boom'});
      await expectLater(
        api.get('/data'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.statusCode,
            'statusCode',
            422,
          ),
        ),
      );
    });
  });

  group('ApiService sessions (no refresh token on v2)', () {
    test('a 401 on a signed-in request ends the session', () async {
      final storage = MockStorageService();
      var signedOut = 0;
      final api = _apiReturning(
        status: 401,
        body: {'message': 'Unauthorized'},
        storage: storage,
        token: 'session-token',
        onUnauthenticated: () => signedOut++,
      );

      await expectLater(
        api.get('/data'),
        throwsA(isA<UnauthorizedException>()),
      );
      verify(storage.clearSession).called(1);
      expect(signedOut, 1);
    });

    test('a wrong password (401 on sign-in) keeps the session', () async {
      final storage = MockStorageService();
      var signedOut = 0;
      final api = _apiReturning(
        status: 401,
        body: {'code': 'INVALID_EMAIL_OR_PASSWORD', 'message': 'Invalid'},
        storage: storage,
        token: 'session-token',
        onUnauthenticated: () => signedOut++,
      );

      await expectLater(
        api.post(ApiEndpoints.login, {'email': 'a@b.c', 'password': 'x'}),
        throwsA(isA<UnauthorizedException>()),
      );
      verifyNever(storage.clearSession);
      expect(signedOut, 0);
    });
  });

  group('ApiService.isSafeToRetry', () {
    RequestOptions req(String method, [Map<String, dynamic>? headers]) =>
        RequestOptions(path: '/x', method: method, headers: headers);

    test('retries idempotent methods', () {
      for (final m in ['GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE']) {
        expect(ApiService.isSafeToRetry(req(m)), isTrue, reason: m);
      }
    });

    test('does not retry POST/PATCH without an idempotency key', () {
      expect(ApiService.isSafeToRetry(req('POST')), isFalse);
      expect(ApiService.isSafeToRetry(req('PATCH')), isFalse);
    });

    test('retries a POST carrying an idempotency key', () {
      expect(
        ApiService.isSafeToRetry(
          req('POST', {ApiService.idempotencyKeyHeader: 'k1'}),
        ),
        isTrue,
      );
    });
  });
}
