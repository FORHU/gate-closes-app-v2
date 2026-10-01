import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/domain/repositories/terminal_echo_repository.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:gate_closes/features/terminal_echo/presentation/pages/echo_preview_dialog.dart';
import 'package:gate_closes/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/signed_in_auth.dart';

class MockTerminalEchoRepository extends Mock
    implements TerminalEchoRepository {}

void main() {
  TerminalEchoEntity echoFrom(String sender) => TerminalEchoEntity(
        id: 'e1',
        senderId: sender,
        textMessage: 'Gate 12 is packed',
        airportIata: 'MNL',
        createdAt: DateTime(2026, 9, 29),
      );

  Future<void> pumpCard(
    WidgetTester tester, {
    required String affinity,
    required String sender,
  }) async {
    final repo = MockTerminalEchoRepository();
    when(() => repo.getEchoById('e1'))
        .thenAnswer((_) async => Right(echoFrom(sender)));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          signedInAuthOverride, // signed in as u1
          terminalEchoRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: EchoPreviewDialog(echoId: 'e1', affinity: affinity),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a Parallel Soul pin offers to start a conversation', (
    tester,
  ) async {
    await pumpCard(tester, affinity: 'parallel_soul', sender: 'u2');

    expect(find.text('PARALLEL SOUL'), findsOneWidget);
    expect(find.text('Gate 12 is packed'), findsOneWidget);
    expect(find.text('START CONVERSATION'), findsOneWidget);
  });

  testWidgets('a Terminal Echo pin has no conversation action', (
    tester,
  ) async {
    await pumpCard(tester, affinity: 'terminal_echo', sender: 'u2');

    expect(find.text('TERMINAL ECHO'), findsOneWidget);
    expect(find.text('START CONVERSATION'), findsNothing);
  });

  testWidgets('your own echo has no conversation action', (tester) async {
    await pumpCard(tester, affinity: 'baton_touch', sender: 'u1');

    expect(find.text('START CONVERSATION'), findsNothing);
  });
}
