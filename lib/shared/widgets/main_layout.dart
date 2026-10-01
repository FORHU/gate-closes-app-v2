import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/airport_gate_dialog.dart';
import 'package:gate_closes/shared/widgets/ambient_background.dart';
import 'package:gate_closes/shared/widgets/map_bottom_nav.dart';
import 'package:go_router/go_router.dart';

/// App shell, following the Expo app's map shell: Map (home) · Feed ·
/// [create echo] · Connections · Settings, with the map drawn edge to edge
/// behind the navigation bar.
class MainLayout extends StatelessWidget {
  const MainLayout({required this.child, super.key});

  final Widget child;

  static const List<String> _routes = [
    RouteNames.home,
    RouteNames.feed,
    RouteNames.connections,
    RouteNames.profile,
  ];

  static int _indexFor(String location) {
    for (var i = 1; i < _routes.length; i++) {
      if (location.startsWith(_routes[i])) return i;
    }
    return location == RouteNames.home ? 0 : -1;
  }

  Future<void> _createEcho(BuildContext context) async {
    // Expo gates echo creation on a live airport check.
    final proceed = await AirportGateDialog.show(context);
    if (proceed && context.mounted) {
      unawaited(context.push(RouteNames.createEcho));
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);
    final isMap = index == 0;

    return Scaffold(
      backgroundColor: context.colors.background,
      // The map runs under the bar; other tabs lay out above it.
      extendBody: isMap,
      body: isMap ? child : AmbientBackground(child: child),
      bottomNavigationBar: MapBottomNav(
        tabs: [
          const MapNavTab(icon: Icons.map_outlined, label: 'Map'),
          const MapNavTab(icon: Icons.list_rounded, label: 'Feed'),
          MapNavTab(icon: Icons.hub_outlined, label: context.l10n.connections),
          const MapNavTab(icon: Icons.settings_outlined, label: 'Settings'),
        ],
        currentIndex: index,
        onTabSelected: (i) => context.go(_routes[i]),
        onActionPressed: () => unawaited(_createEcho(context)),
      ),
    );
  }
}
