import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_point.dart';
import 'package:gate_closes/features/worldMap/presentation/widgets/country_airports_sheet.dart';

void main() {
  const mnl = AirportPoint(
    iata: 'MNL',
    name: 'Ninoy Aquino International Airport',
    longitude: 121.02,
    latitude: 14.51,
    countryCode: 'PH',
  );
  const bag = AirportPoint(
    iata: 'BAG',
    name: 'Loakan Airport',
    longitude: 120.62,
    latitude: 16.38,
    countryCode: 'PH',
  );

  testWidgets('lists the country airports and returns the one picked',
      (tester) async {
    AirportPoint? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => picked = await CountryAirportsSheet.show(
                context,
                country: 'Philippines',
                airports: const [mnl, bag],
                counts: const {'MNL': 12, 'BAG': 1},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('PHILIPPINES'), findsOneWidget);
    expect(find.text('2 AIRPORTS · 13 ECHOES'), findsOneWidget);
    await tester.tap(find.text('Loakan Airport'));
    await tester.pumpAndSettle();
    expect(picked, bag);
  });
}
