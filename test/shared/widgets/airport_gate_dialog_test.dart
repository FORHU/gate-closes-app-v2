import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/shared/widgets/airport_gate_dialog.dart';
import 'package:gate_closes/theme/app_theme.dart';

class _FakeAirportController extends AirportController {
  _FakeAirportController(this.result);

  final AirportEntity? result;

  @override
  Future<void> detectAirport() async {
    state = AirportState(airport: result);
  }
}

void main() {
  Future<void> openGate(WidgetTester tester, AirportEntity? detected) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          airportControllerProvider
              .overrideWith(() => _FakeAirportController(detected)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => AirportGateDialog.show(context),
              child: const Text('echo'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('echo'));
    await tester.pumpAndSettle();
  }

  testWidgets('inside an airport: offers to create the echo', (tester) async {
    await openGate(
      tester,
      const AirportEntity(
        id: 'MNL',
        name: 'Ninoy Aquino International',
        iata: 'MNL',
        detectionState: AirportDetectionState.insideAirport,
      ),
    );

    expect(find.text('Airport Detected'), findsOneWidget);
    expect(find.textContaining('Ninoy Aquino International'), findsOneWidget);
    expect(find.text('Create an Echo'), findsOneWidget);
  });

  testWidgets('outside an airport: explains and blocks', (tester) async {
    await openGate(tester, null);

    expect(find.text('Outside Airport'), findsOneWidget);
    expect(find.text('Create an Echo'), findsNothing);
    await tester.tap(find.text('Understood'));
    await tester.pumpAndSettle();
    expect(find.text('Outside Airport'), findsNothing);
  });
}
