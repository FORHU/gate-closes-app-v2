import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/domain/repositories/terminal_echo_repository.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:gate_closes/features/terminal_echo/presentation/pages/feed_page.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/signed_in_auth.dart';

const _mnl = AirportEntity(
  id: 'MNL',
  name: 'Ninoy Aquino International',
  iata: 'MNL',
);
const _sin = AirportEntity(id: 'SIN', name: 'Singapore Changi', iata: 'SIN');

class _FakeAirportController extends AirportController {
  @override
  Future<void> detectAirport() async {
    state = const AirportState(airport: _mnl);
  }
}

/// Records which feeds were requested; returns empty feeds (no socket).
class _FakeEchoRepository implements TerminalEchoRepository {
  final List<String?> requested = [];

  @override
  Future<Either<Failure, List<TerminalEchoEntity>>> getEchoes({
    String? airportIata,
  }) async {
    requested.add(airportIata);
    return const Left(ServerFailure('offline'));
  }

  @override
  Future<Either<Failure, TerminalEchoEntity>> createEcho({
    required String textMessage,
    required String airportName,
    required LocationCoordinates coordinates,
    required String fileUrl,
    required String fileName,
    double audioDuration = 0,
    List<double> waveformData = const [],
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> updateReaction({
    required String echoId,
    required EchoReactionType reaction,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> incrementListen(String echoId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, TerminalEchoEntity>> getEchoById(String id) =>
      throw UnimplementedError();
}

void main() {
  /// Opens the feed, then picks [airport] on a stand-in search page.
  Future<_FakeEchoRepository> searchFor(
    WidgetTester tester,
    AirportEntity airport,
  ) async {
    final repo = _FakeEchoRepository();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const FeedPage()),
        GoRoute(
          path: RouteNames.airportSearch,
          builder: (context, _) => TextButton(
            onPressed: () => context.pop(airport),
            child: const Text('pick'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          signedInAuthOverride,
          airportControllerProvider.overrideWith(_FakeAirportController.new),
          terminalEchoRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.requested, ['MNL']);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('search loads the picked airport; clearing goes back',
      (tester) async {
    final repo = await searchFor(tester, _sin);

    expect(repo.requested, ['MNL', 'SIN']);
    expect(find.text('Terminal Echo — SIN'), findsOneWidget);
    expect(find.text('Singapore Changi'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to my airport'));
    await tester.pumpAndSettle();

    expect(repo.requested, ['MNL', 'SIN', 'MNL']);
    expect(find.text('Terminal Echo — MNL'), findsOneWidget);
    expect(find.text('Singapore Changi'), findsNothing);
  });

  testWidgets('picking the detected airport shows no override chip',
      (tester) async {
    final repo = await searchFor(tester, _mnl);

    expect(repo.requested, ['MNL', 'MNL']);
    expect(find.byType(InputChip), findsNothing);
  });
}
