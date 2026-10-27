import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/terminal_echo/presentation/pages/create_echo_page.dart';

void main() {
  testWidgets('left-airport notice says the echo is not posted', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await showLeftAirportNotice(context, 'Changi');
              closed = true;
            },
            child: const Text('send'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('send'));
    await tester.pumpAndSettle();
    expect(find.text('Outside Terminal Zone'), findsOneWidget);
    expect(find.textContaining("You've left Changi"), findsOneWidget);
    expect(find.text('Post Anyway'), findsNothing);

    await tester.tap(find.text('Understood'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(find.text('Outside Terminal Zone'), findsNothing);
  });
}
