/// Centralized API paths. Keep every endpoint here — never inline path strings
/// in data sources. Paths are relative to `AppConfig.instance.baseUrl`.
class ApiEndpoints {
  ApiEndpoints._();

  static const String login = '/auth/login';

  /// Signup wizard (4 steps, verified against `user.auth.route.ts`).
  static const String registerEmail = '/auth/register-email';
  static const String verifyEmail = '/auth/verify-email';
  static const String resendCode = '/auth/resend-code';
  static const String setPassword = '/auth/set-password';
  static const String setUsernameGender = '/auth/set-username-gender';

  /// Forgot-password wizard (4 steps, same shape as signup).
  static const String forgotPassword = '/auth/forgot-password';
  static const String resendResetCode = '/auth/resend-reset-code';
  static const String verifyResetCode = '/auth/verify-reset-code';
  static const String resetPassword = '/auth/reset-password';

  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String googleAuth = '/auth/login-or-register-google';
  static const String changePassword = '/auth/change-password';
  static const String editProfile = '/auth/edit-profile';

  /// Airport detection endpoints
  static const String airportCheckInside = '/airport/check-inside-airport';
  static const String airportCheckBoundary =
      '/airport/check-inside-airport-boundary';
  static const String airportNearby = '/airport/nearby';
  static const String airportSearch = '/airport/search';
  static const String airportGeoJson = '/airport/geojson';

  /// Flight Ticket endpoints
  static const String flightTicket = '/flight-ticket';

  /// File upload (audio only, 10MB max — see `s3.controller.ts`). Shared by
  /// Terminal Echo's composer and Messaging's voice messages.
  static const String s3Upload = '/s3/upload';

  /// Terminal Echo endpoints
  static const String terminalEcho = '/terminal-echo';
  static const String terminalEchoMap = '/terminal-echo/map';
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
