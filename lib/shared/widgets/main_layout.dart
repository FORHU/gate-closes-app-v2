import 'package:flutter/material.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/routes/route_names.dart';
import 'package:flutter_template/shared/widgets/ambient_background.dart';
import 'package:flutter_template/shared/widgets/animated_bottom_navigation.dart';
import 'package:go_router/go_router.dart';

/// App shell: hosts the routed [child] and the premium glass bottom navigation.
///
/// ADD or REMOVE tabs by editing `_destinations` — no other changes needed.
class MainLayout extends StatelessWidget {
  const MainLayout({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ── Tab definitions ────────────────────────────────────────────────────
    // Each entry pairs a [NavBarItem] with its root route. The active tab is
    // resolved by matching the current location against `route`.
    //
    // TO CUSTOMIZE: replace the placeholder entries below with your own
    // feature pages. Keep `RouteNames.*` in sync with `route_names.dart`.
    final destinations = <_Destination>[
      const _Destination(
        item: NavBarItem(
          label: 'Feed',
          icon: Icons.graphic_eq_rounded,
          activeIcon: Icons.graphic_eq_rounded,
        ),
        route: RouteNames.feed,
      ),
      const _Destination(
        item: NavBarItem(
          label: 'Map',
          icon: Icons.map_outlined,
          activeIcon: Icons.map_rounded,
        ),
        route: RouteNames.worldMap,
      ),
      // The "Home" route (`/`) renders ConnectionsPage directly — see
      // app_routes.dart. There's no separate fake-data Home screen anymore
      // (that was unmodified flutter_template scaffold hitting a
      // nonexistent `/users` endpoint); this tab's content IS Connections.
      _Destination(
        item: NavBarItem(
          label: context.l10n.connections,
          icon: Icons.people_alt_outlined,
          activeIcon: Icons.people_alt_rounded,
        ),
        route: RouteNames.home,
      ),
      _Destination(
        item: NavBarItem(
          label: context.l10n.profile,
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
        ),
        route: RouteNames.profile,
      ),
    ];

    // ── Active tab detection ────────────────────────────────────────────────
    final location = GoRouterState.of(context).matchedLocation;
    var currentIndex = destinations.indexWhere(
      (d) => d.route != RouteNames.home && location.startsWith(d.route),
    );
    if (currentIndex == -1) {
      currentIndex = destinations.indexWhere((d) => d.route == RouteNames.home);
      if (currentIndex == -1) currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: AmbientBackground(child: child),
      bottomNavigationBar: AnimatedBottomNavigation(
        items: [for (final d in destinations) d.item],
        currentIndex: currentIndex,
        onTap: (index) => context.go(destinations[index].route),
      ),
    );
  }
}

class _Destination {
  const _Destination({required this.item, required this.route});

  final NavBarItem item;
  final String route;
}
