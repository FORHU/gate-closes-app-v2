import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/services/storage_service.dart';
import 'package:flutter_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_template/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:flutter_template/features/auth/presentation/pages/login_page.dart';
import 'package:flutter_template/features/auth/presentation/pages/onboarding_page.dart';
import 'package:flutter_template/features/auth/presentation/pages/register_page.dart';
import 'package:flutter_template/features/connections/presentation/pages/connections_page.dart';
import 'package:flutter_template/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter_template/features/terminal_echo/presentation/pages/create_echo_page.dart';
import 'package:flutter_template/features/terminal_echo/presentation/pages/feed_page.dart';
import 'package:flutter_template/features/worldMap/presentation/pages/world_map_page.dart';
import 'package:flutter_template/routes/route_names.dart';
import 'package:flutter_template/shared/widgets/main_layout.dart';
import 'package:go_router/go_router.dart';

/// Listenable helper to notify GoRouter whenever auth state changes.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        if (previous?.isAuthenticated != next.isAuthenticated) {
          notifyListeners();
        }
      },
    );
  }

  final Ref _ref;
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// The app's router. `redirect` guards routes based on auth state; the login
/// form and logout button also navigate explicitly with `context.go(...)`.
final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: RouteNames.home,
    refreshListenable: notifier,
    redirect: (context, state) {
      final isAuth = ref.read(authControllerProvider).isAuthenticated;
      final goingToLogin = state.matchedLocation == RouteNames.login;
      final goingToRegister = state.matchedLocation == RouteNames.register;
      final goingToForgotPassword =
          state.matchedLocation == RouteNames.forgotPassword;
      final goingToPreAuthPage =
          goingToLogin || goingToRegister || goingToForgotPassword;

      if (!isAuth) {
        return goingToPreAuthPage ? null : RouteNames.login;
      }

      // Onboarding gate: new users see it once.
      final seenOnboarding = ref.read(storageServiceProvider).onboardingSeen;
      if (!seenOnboarding) {
        final goingToOnboarding =
            state.matchedLocation == RouteNames.onboarding;
        return goingToOnboarding ? null : RouteNames.onboarding;
      }

      // Reaching here while authenticated and still on a pre-auth page means
      // the forgot-password wizard just logged the user in — bounce home.
      if (goingToPreAuthPage) return RouteNames.home;
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      // Outside the shell (no bottom nav) — pushed as a full-screen modal.
      GoRoute(
        path: RouteNames.createEcho,
        builder: (context, state) => const CreateEchoPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: RouteNames.home,
            builder: (context, state) => const ConnectionsPage(),
          ),
          GoRoute(
            path: RouteNames.recommendations,
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Recommendations'))),
          ),
          GoRoute(
            path: RouteNames.worldMap,
            builder: (context, state) => const WorldMapPage(),
          ),
          GoRoute(
            path: RouteNames.feed,
            builder: (context, state) => const FeedPage(),
          ),
          GoRoute(
            path: RouteNames.profile,
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
});
