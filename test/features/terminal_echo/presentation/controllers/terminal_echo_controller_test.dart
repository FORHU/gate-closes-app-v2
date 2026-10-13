import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/config/app_config.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/echo_page.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/domain/repositories/terminal_echo_repository.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/signed_in_auth.dart';

TerminalEchoEntity _echo(String id) => TerminalEchoEntity(
      id: id,
      senderId: 'u2',
      textMessage: '',
      airportIata: 'MNL',
      createdAt: DateTime(2026, 10, 13),
    );

/// Serves pages keyed by cursor (null = first page) and records requests.
class _PagedRepository implements TerminalEchoRepository {
  _PagedRepository(this.pages);

  final Map<String?, EchoPage> pages;
  final List<String?> cursors = [];

  @override
  Future<Either<Failure, EchoPage>> getEchoes({
    String? airportIata,
    String? cursor,
  }) async {
    cursors.add(cursor);
    return Right(pages[cursor]!);
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
  setUpAll(() => AppConfig.instance = const AppConfig.prod());

  test('loads the feed a page at a time until the last one', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _PagedRepository({
      null: EchoPage(echoes: [_echo('a'), _echo('b')], nextCursor: 'c1'),
      // 'b' again: an echo can't appear twice even if pages overlap.
      'c1': EchoPage(echoes: [_echo('b'), _echo('c')], nextCursor: 'c2'),
      'c2': EchoPage(echoes: [_echo('d')]),
    });
    final container = ProviderContainer(
      overrides: [
        signedInAuthOverride,
        sharedPreferencesProvider.overrideWithValue(prefs),
        terminalEchoRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(terminalEchoControllerProvider.notifier);
    List<String> ids() => [
          for (final e in container.read(terminalEchoControllerProvider).echoes)
            e.id,
        ];

    await controller.loadFeed('MNL');
    expect(ids(), ['a', 'b']);
    expect(container.read(terminalEchoControllerProvider).hasMore, isTrue);

    await controller.loadMore();
    await controller.loadMore();
    expect(ids(), ['a', 'b', 'c', 'd']);
    expect(container.read(terminalEchoControllerProvider).hasMore, isFalse);

    // Nothing left: no more requests.
    await controller.loadMore();
    expect(repo.cursors, [null, 'c1', 'c2']);
  });
}
