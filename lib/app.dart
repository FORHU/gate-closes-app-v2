import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/config/app_config.dart';
import 'package:gate_closes/core/location/simulated_airport.dart';
import 'package:gate_closes/core/notifications/notification_coordinator.dart';
import 'package:gate_closes/core/services/theme_controller.dart';
import 'package:gate_closes/l10n/generated/app_localizations.dart';
import 'package:gate_closes/routes/app_routes.dart';
import 'package:gate_closes/theme/app_theme.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    // Live notifications, the flight reminder, and taps → screens.
    ref
      ..watch(notificationCoordinatorProvider)
      ..watch(notificationTapRoutingProvider);
    final themeMode = ref.watch(themeModeProvider);
    final simulated = ref.watch(simulatedAirportProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConfig.instance.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      // On every screen while a dev simulated airport is active, so its
      // data is never mistaken for real. An overlay, not a wrapper: the app
      // must keep its place in the tree when the banner comes and goes.
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          child!,
          if (simulated != null)
            IgnorePointer(
              child: Banner(
                message: 'SIM ${simulated.iata}',
                location: BannerLocation.topStart,
                textDirection: TextDirection.ltr,
                layoutDirection: TextDirection.ltr,
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}
