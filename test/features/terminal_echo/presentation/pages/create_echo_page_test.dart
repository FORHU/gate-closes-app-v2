import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/terminal_echo/presentation/pages/create_echo_page.dart';

void main() {
  /// Opens the outside-airport alert, taps [button], returns the answer.
  Future<bool?> answerAlert(WidgetTester tester, String button) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await confirmPostOutsideAirport(context, 'Changi'),
            child: const Text('send'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('send'));
    await tester.pumpAndSettle();
    expect(find.text('Outside Terminal Zone'), findsOneWidget);
    expect(find.textContaining('protected radius of Changi'), findsOneWidget);

    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('outside-airport alert: Post Anyway proceeds', (tester) async {
    expect(await answerAlert(tester, 'Post Anyway'), isTrue);
  });

  testWidgets('outside-airport alert: Cancel stops the post', (tester) async {
    expect(await answerAlert(tester, 'Cancel'), isFalse);
  });
}
