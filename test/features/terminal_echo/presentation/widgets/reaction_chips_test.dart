import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/terminal_echo/presentation/widgets/reaction_chips.dart';
import 'package:gate_closes/theme/app_theme.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Map<String, int> counts,
    VoidCallback? onReact,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ReactionChips(
              counts: counts,
              mine: const {'love'},
              onReact: onReact ?? () {},
            ),
          ),
        ),
      );

  testWidgets('one chip per reaction in use, not a single total', (
    tester,
  ) async {
    await pump(tester, counts: {'love': 2, 'wow': 1, 'angry': 1, 'sad': 0});
    expect(find.text('❤️ 2'), findsOneWidget);
    expect(find.text('😮 1'), findsOneWidget);
    expect(find.text('😠 1'), findsOneWidget);
    expect(find.textContaining('😢'), findsNothing);
    expect(find.text('4'), findsNothing);
  });

  testWidgets('the react button calls onReact', (tester) async {
    var tapped = false;
    await pump(tester, counts: const {}, onReact: () => tapped = true);
    await tester.tap(find.bySemanticsLabel('React'));
    expect(tapped, isTrue);
  });
}
