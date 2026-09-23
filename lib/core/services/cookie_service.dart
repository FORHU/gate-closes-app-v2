import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages cross-platform cookies for HTTP requests.
///
/// On Flutter Web, cookies and credentials are natively managed by the browser
/// through `withCredentials = true`.
/// On native platforms (iOS, Android, macOS, Windows, Linux), [CookieJar]
/// maintains an in-memory session jar.
class CookieService {
  CookieService({CookieJar? jar}) : _jar = jar ?? CookieJar();

  final CookieJar _jar;

  CookieJar get jar => _jar;

  /// Clears stored cookies for the session.
  Future<void> clearCookies() async {
    if (!kIsWeb) {
      await _jar.deleteAll();
    }
  }
}

final cookieServiceProvider = Provider<CookieService>((ref) {
  return CookieService();
});
