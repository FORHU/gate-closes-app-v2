/// Path constants for go_router. Reference these instead of raw strings.
class RouteNames {
  RouteNames._();

  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';

  /// Home: the map, as in the Expo app's map shell.
  static const String home = '/';
  static const String connections = '/connections';
  static const String feed = '/feed';
  static const String createEcho = '/feed/create';
  static const String echoThread = '/feed/thread/:echoId';
  static String echoThreadFor(String echoId) => '/feed/thread/$echoId';
  static const String airportSearch = '/feed/airport-search';

  /// Card for a tapped map pin (`?type=` is the pin's affinity type key).
  static const String mapEcho = '/map/echo/:echoId';
  static String mapEchoFor(String echoId, String type) =>
      '/map/echo/$echoId?type=$type';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String changePassword = '/profile/change-password';
  static const String mapLighting = '/profile/map-lighting';
  static const String addBoardingPass = '/add-boarding-pass';

  /// A conversation with a traveler that may not exist yet (`?type=` is the
  /// API conversation type, e.g. `parallel_soul`).
  static const String connectionDraft = '/connections/dm/:otherUserId';
  static String connectionDraftFor(String otherUserId, String type) =>
      '/connections/dm/$otherUserId?type=$type';
}
