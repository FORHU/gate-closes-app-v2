import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/presentation/widgets/echo_stack_sheet.dart';

TerminalEchoMapNodeEntity _echo(
  String id,
  EchoNodeKind kind, {
  DateTime? at,
  int listens = 0,
  int reactions = 0,
}) =>
    TerminalEchoMapNodeEntity(
      id: id,
      senderId: '',
      nodeKind: kind,
      latitude: 14.509,
      longitude: 121.019,
      createdAt: at,
      listenCount: listens,
      reactionCount: reactions,
    );

void main() {
  final now = DateTime.now();

  test('newest first, undated last', () {
    final sorted = EchoStackSheet.sorted([
      _echo('old', EchoNodeKind.terminalEcho, at: DateTime(2026, 10, 2)),
      _echo('none', EchoNodeKind.terminalEcho),
      _echo('new', EchoNodeKind.terminalEcho, at: DateTime(2026, 10, 5)),
    ]);
    expect(sorted.map((e) => e.id), ['new', 'old', 'none']);
  });

  test('age labels', () {
    final t = DateTime(2026, 10, 5, 12);
    expect(EchoStackSheet.age(null, t), '');
    expect(
      EchoStackSheet.age(t.subtract(const Duration(seconds: 20)), t),
      'Just now',
    );
    expect(
      EchoStackSheet.age(t.subtract(const Duration(minutes: 5)), t),
      '5 min ago',
    );
    expect(
      EchoStackSheet.age(t.subtract(const Duration(hours: 3)), t),
      '3 h ago',
    );
    expect(
      EchoStackSheet.age(t.subtract(const Duration(days: 2)), t),
      '2 d ago',
    );
  });

  testWidgets('lists the echoes on one spot and returns the one tapped',
      (tester) async {
    TerminalEchoMapNodeEntity? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await EchoStackSheet.show(context, [
                _echo(
                  'a',
                  EchoNodeKind.parallelSoul,
                  at: now.subtract(const Duration(minutes: 5)),
                  listens: 1,
                  reactions: 2,
                ),
                _echo(
                  'b',
                  EchoNodeKind.batonTouch,
                  at: now.subtract(const Duration(hours: 1)),
                ),
              ]);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('2 echoes here'), findsOneWidget);
    expect(find.text('Parallel Soul'), findsOneWidget);
    expect(find.text('5 min ago · 1 listen · 2 reactions'), findsOneWidget);
    expect(find.text('Baton Touch'), findsOneWidget);

    await tester.tap(find.text('Baton Touch'));
    await tester.pumpAndSettle();

    expect(picked?.id, 'b');
    expect(find.text('2 echoes here'), findsNothing);
  });
}
