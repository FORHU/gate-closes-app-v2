import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_template/core/config/app_config.dart';
import 'package:flutter_template/core/services/api_service.dart';
import 'package:flutter_template/core/services/cookie_service.dart';
import 'package:flutter_template/core/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  setUpAll(() {
    AppConfig.instance = const AppConfig.prod();
  });

  group('CookieService', () {
    test('initializes with default CookieJar', () {
      final service = CookieService();
      expect(service.jar, isA<CookieJar>());
    });

    test('accepts custom CookieJar and clears cookies', () async {
      final customJar = CookieJar();
      final service = CookieService(jar: customJar);

      await service.jar.saveFromResponse(
        Uri.parse('http://localhost:3002'),
        [Cookie('accessToken', 'test-token')],
      );

      var cookies =
          await service.jar.loadForRequest(Uri.parse('http://localhost:3002'));
      expect(cookies.length, 1);
      expect(cookies.first.name, 'accessToken');

      await service.clearCookies();
      cookies = await service.jar.loadForRequest(
        Uri.parse('http://localhost:3002'),
      );
      expect(cookies.isEmpty, true);
    });

    test(
      'ApiService attaches CookieManager when cookieService is provided',
      () {
        final storage = MockStorageService();
        when(storage.readToken).thenAnswer((_) async => null);
        when(storage.readRefreshToken).thenAnswer((_) async => null);

        final cookieService = CookieService();
        final api = ApiService(
          storage: storage,
          cookieService: cookieService,
        );

        final hasCookieManager = api.client.interceptors.any(
          (i) => i is CookieManager,
        );
        expect(hasCookieManager, isTrue);
      },
    );
  });
}
