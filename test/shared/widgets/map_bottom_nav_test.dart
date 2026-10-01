import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/shared/widgets/map_bottom_nav.dart';
import 'package:gate_closes/theme/app_theme.dart';

void main() {
  const tabs = [
    MapNavTab(icon: Icons.map_outlined, label: 'Map'),
    MapNavTab(icon: Icons.list_rounded, label: 'Feed'),
    MapNavTab(icon: Icons.hub_outlined, label: 'Connections'),
    MapNavTab(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  testWidgets('labels only the active tab; tabs and action are tappable', (
    tester,
  ) async {
    int? selected;
    var actions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          bottomNavigationBar: MapBottomNav(
            tabs: tabs,
            currentIndex: 0,
            onTabSelected: (i) => selected = i,
            onActionPressed: () => actions++,
          ),
        ),
      ),
    );

    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Feed'), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    expect(selected, 3);

    await tester.tap(find.byTooltip('Create an echo'));
    expect(actions, 1);
  });
}
