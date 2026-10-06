import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_offer.dart';
import 'package:gate_closes/features/worldMap/presentation/widgets/offer_banner.dart';
import 'package:gate_closes/features/worldMap/presentation/widgets/offer_sheet.dart';

void main() {
  const voucher = MapOffer(
    id: 'v1',
    airportIata: 'MNL',
    kind: 'lounge_pass',
    title: 'Lounge day pass',
    body: 'Rest before your flight.',
    ctaLabel: 'See the lounge',
    ctaUrl: 'https://example.com/lounge',
    claimable: true,
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    MapOffer offer = voucher,
    Future<Either<Failure, OfferReward>> Function()? onClaim,
    Future<void> Function()? onOpenLink,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfferSheet(
              offer: offer,
              onOpenLink: onOpenLink ?? () async {},
              onClaim: onClaim ??
                  () async => const Right(OfferReward({'code': 'GATE20'})),
            ),
          ),
        ),
      );

  testWidgets('shows the offer and its kind in words', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Lounge pass · MNL'), findsOneWidget);
    expect(find.text('Lounge day pass'), findsOneWidget);
    expect(find.text('Rest before your flight.'), findsOneWidget);
    expect(find.text('See the lounge'), findsOneWidget);
  });

  testWidgets('claiming reveals the code', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Claim'));
    await tester.pumpAndSettle();

    expect(find.text('Claimed!'), findsOneWidget);
    expect(find.text('GATE20'), findsOneWidget);
    expect(find.text('Claim'), findsNothing);
  });

  testWidgets("a refused claim shows the API's reason", (tester) async {
    await pumpSheet(
      tester,
      onClaim: () async => const Left(ServerFailure('This offer has run out.')),
    );

    await tester.tap(find.text('Claim'));
    await tester.pumpAndSettle();

    expect(find.text('This offer has run out.'), findsOneWidget);
    expect(find.text('Claim'), findsOneWidget, reason: 'can try again');
  });

  testWidgets('no Claim without a reward; the link button opens the link',
      (tester) async {
    var opened = 0;
    await pumpSheet(
      tester,
      offer: const MapOffer(
        id: 'a1',
        airportIata: 'MNL',
        kind: 'ad',
        title: 'Duty free',
        ctaUrl: 'https://example.com',
      ),
      onOpenLink: () async => opened++,
    );

    expect(find.text('Claim'), findsNothing);
    await tester.tap(find.text('Open'));
    expect(opened, 1);
  });

  testWidgets('the banner opens the offer and can be hidden', (tester) async {
    var opened = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfferBanner(
            offer: voucher,
            onOpen: () => opened++,
            onDismiss: () => dismissed++,
          ),
        ),
      ),
    );

    expect(find.text('Lounge pass at MNL'), findsOneWidget);
    await tester.tap(find.text('Lounge day pass'));
    await tester.tap(find.byTooltip('Hide offer'));
    expect((opened, dismissed), (1, 1));
  });
}
