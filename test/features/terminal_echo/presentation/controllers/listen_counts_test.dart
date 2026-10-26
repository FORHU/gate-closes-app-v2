import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/listen_counts.dart';

/// Shows [own] for echo `e1` the way the echo cards do.
class _Count extends ConsumerWidget {
  const _Count(this.own);

  final int own;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
        '${watchListens(ref, 'e1', own)}',
        textDirection: TextDirection.ltr,
      );
}

void main() {
  test('keeps the highest count per id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(listenCountsProvider.notifier)
      ..record('e1', 11)
      ..record('e1', 10) // an older answer arriving late
      ..record('r1', 3);

    expect(container.read(listenCountsProvider), {'e1': 11, 'r1': 3});
  });

  testWidgets('a card shows a recorded listen at once (GC-67)', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _Count(10)),
    );
    expect(find.text('10'), findsOneWidget);

    container.read(listenCountsProvider.notifier).record('e1', 11);
    await tester.pump();

    expect(find.text('11'), findsOneWidget);
  });

  testWidgets('a fresher copy of the echo wins over an older record',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(listenCountsProvider.notifier).record('e1', 11);

    // The feed reloaded: others listened meanwhile.
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _Count(14)),
    );

    expect(find.text('14'), findsOneWidget);
  });
}
