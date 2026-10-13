/// Centralized API paths. Keep every endpoint here — never inline path strings
/// in data sources. Paths are relative to `AppConfig.instance.baseUrl`.
class ApiEndpoints {
  ApiEndpoints._();

  /// Auth on gate-closes-api-v2 (Better Auth; see its docs/AUTH.md). Sign-in
  /// responses carry the session token; there is no refresh token.
  static const String login = '/auth/sign-in/email';

  /// Sends a 4-digit code: `type` "sign-in" for sign-up (and resend),
  /// "forget-password" for a password reset (and resend).
  static const String sendOtp = '/auth/email-otp/send-verification-otp';

  /// Sign-up step 2: the code signs the new user in (session token).
  static const String signInWithOtp = '/auth/sign-in/email-otp';

  /// Sign-up steps 3 and 4, with the session from step 2.
  static const String setPassword = '/auth/set-password';
  static const String setUsernameGender = '/auth/set-username-gender';

  /// Password reset: check the code (doesn't use it up), then reset with it.
  static const String checkOtp = '/auth/email-otp/check-verification-otp';
  static const String resetPassword = '/auth/email-otp/reset-password';

  static const String logout = '/auth/sign-out';
  static const String me = '/auth/me';
  static const String googleAuth = '/auth/sign-in/social';
  static const String changePassword = '/auth/change-password';
  static const String editProfile = '/auth/edit-profile';

  /// Airport detection endpoints
  static const String airportCheckInside = '/airport/check-inside-airport';
  static const String airportCheckBoundary =
      '/airport/check-inside-airport-boundary';
  static const String airportNearby = '/airport/nearby';
  static const String airportSearch = '/airport/search';
  static const String airportGeoJson = '/airport/geojson';

  /// The caller's own test airport (dev builds, `airports:simulate`).
  static const String airportTest = '/airport/test';

  /// Flight Ticket endpoints
  static const String flightTicket = '/flight-ticket';

  /// File upload (audio only, 10MB max — see `s3.controller.ts`). Shared by
  /// Terminal Echo's composer and Messaging's voice messages.
  static const String s3Upload = '/s3/upload';

  /// Offers (ads, vouchers) at an airport, for the map.
  static const String offers = '/offers';
  static String offerEvents(String id) => '/offers/$id/events';
  static String offerClaim(String id) => '/offers/$id/claim';

  /// Terminal Echo endpoints
  static const String terminalEcho = '/terminal-echo';
  static const String terminalEchoMap = '/terminal-echo/map';
  static const String terminalEchoMapCounts = '/terminal-echo/map/counts';
  static String terminalEchoListen(String id) => '/terminal-echo/$id/listen';
  static String terminalEchoReaction(String id) =>
      '/terminal-echo/$id/reaction';

  /// Terminal Echo Reply endpoints
  static const String terminalEchoReply = '/terminal-echo-reply';
  static String terminalEchoReplyListen(String id) =>
      '/terminal-echo-reply/$id/listen';
  static String terminalEchoReplyReaction(String id) =>
      '/terminal-echo-reply/$id/reaction';

  /// Conversation / Connections endpoints
  static const String conversations = '/conversations';
  static const String conversationSearch = '/conversations/search';
  static const String conversationExistence = '/conversations/existence';
  static String conversationById(String id) => '/conversations/$id';
  static String conversationRead(String id) => '/conversations/$id/read';
  static String conversationMessages(String id) =>
      '/conversations/$id/messages';
  static String conversationMessageReaction(
    String conversationId,
    String messageId,
  ) =>
      '/conversations/$conversationId/messages/$messageId/reaction';
}
