import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/shared/widgets/in_app_notification_banner.dart';

Future<OverlayState> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: SizedBox.expand())),
  );
  return tester.state<NavigatorState>(find.byType(Navigator)).overlay!;
}

void main() {
  testWidgets('shows the title and body', (tester) async {
    final overlay = await _pumpApp(tester);
    showInAppNotificationBanner(
      overlay,
      title: 'Parallel Soul',
      body: 'alice sent you a voice message',
      onTap: () {},
    );
    await tester.pumpAndSettle();

    expect(find.text('Parallel Soul'), findsOneWidget);
    expect(find.text('alice sent you a voice message'), findsOneWidget);

    // Let the auto-dismiss timer finish so no timer outlives the test.
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a tap opens the target and removes the banner', (tester) async {
    final overlay = await _pumpApp(tester);
    var opened = 0;
    showInAppNotificationBanner(
      overlay,
      title: 'New reply',
      body: 'New reply on your echo at MNL',
      onTap: () => opened++,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New reply'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.text('New reply'), findsNothing);
  });

  testWidgets('a new banner replaces the one on screen', (tester) async {
    final overlay = await _pumpApp(tester);
    showInAppNotificationBanner(
      overlay,
      title: 'First',
      body: 'one',
      onTap: () {},
    );
    await tester.pumpAndSettle();
    showInAppNotificationBanner(
      overlay,
      title: 'Second',
      body: 'two',
      onTap: () {},
    );
    await tester.pumpAndSettle();

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('goes away on its own after 4 seconds', (tester) async {
    final overlay = await _pumpApp(tester);
    showInAppNotificationBanner(
      overlay,
      title: 'Matches nearby',
      body: 'A Parallel Soul just posted at MNL',
      onTap: () {},
    );
    await tester.pumpAndSettle();
    expect(find.text('Matches nearby'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Matches nearby'), findsNothing);
  });
}
