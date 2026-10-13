import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/config/app_config.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google's account picker, reduced to what the API needs: an ID token.
///
/// The token is issued for [serverClientId] (the API's "Web application"
/// OAuth client), which is the audience gate-closes-api-v2 checks. The
/// Android OAuth client is matched by Google from the package name and the
/// signing key's SHA-1; it never appears in code.
class GoogleSignInService {
  GoogleSignInService(this.serverClientId);

  final String serverClientId;
  Future<void>? _initialized;

  /// Without the server client id Google returns no ID token, so the
  /// button is hidden rather than shown broken.
  bool get isConfigured => serverClientId.isNotEmpty;

  Future<void> _init() => _initialized ??=
      GoogleSignIn.instance.initialize(serverClientId: serverClientId);

  /// The ID token for `POST /auth/sign-in/social`, or null when the user
  /// closed the picker. Other failures throw [GoogleSignInException].
  Future<String?> idToken() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'Google returned no ID token.',
        );
      }
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }
  }

  /// Forgets the chosen account so the next sign-in shows the picker again.
  /// Best effort: the app session is what logout really ends.
  Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } on Object {
      // Nothing to undo: the API session is already gone.
    }
  }
}

final googleSignInServiceProvider = Provider<GoogleSignInService>(
  (ref) => GoogleSignInService(AppConfig.instance.googleServerClientId),
);
