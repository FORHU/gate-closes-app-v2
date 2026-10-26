import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/terminal_echo/data/datasources/terminal_echo_socket_service.dart';
import 'package:gate_closes/features/terminal_echo/data/models/terminal_echo_model.dart';
import 'package:gate_closes/features/terminal_echo/data/repositories/terminal_echo_repository_impl.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/domain/repositories/terminal_echo_repository.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/listen_counts.dart';

// --- Dependency wiring ---

final terminalEchoRepositoryProvider = Provider<TerminalEchoRepository>((ref) {
  return TerminalEchoRepositoryImpl(ref.watch(apiServiceProvider));
});

// --- State ---

class TerminalEchoState extends Equatable {
  const TerminalEchoState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.echoes = const [],
    this.nextCursor,
    this.currentAirportIata,
    this.error,
  });

  final bool isLoading;

  /// Fetching the page after [echoes] (see [nextCursor]).
  final bool isLoadingMore;
  final List<TerminalEchoEntity> echoes;

  /// The API's cursor for the next page; null when the feed is complete.
  final String? nextCursor;
  final String? currentAirportIata;
  final String? error;

  bool get hasMore => nextCursor != null;

  static const Object _keep = Object();

  TerminalEchoState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<TerminalEchoEntity>? echoes,
    Object? nextCursor = _keep,
    String? currentAirportIata,
    String? error,
  }) {
    return TerminalEchoState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      echoes: echoes ?? this.echoes,
      nextCursor: identical(nextCursor, _keep)
          ? this.nextCursor
          : nextCursor as String?,
      currentAirportIata: currentAirportIata ?? this.currentAirportIata,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isLoadingMore,
        echoes,
        nextCursor,
        currentAirportIata,
        error,
      ];
}

// --- Controller ---

class TerminalEchoController extends Notifier<TerminalEchoState> {
  TerminalEchoSocketService? _socketService;

  @override
  TerminalEchoState build() {
    // Reset (and drop the socket) whenever the signed-in user changes.
    ref
      ..watch(authControllerProvider.select((s) => s.user?.id))
      ..onDispose(() {
        _socketService?.disconnect();
        _socketService = null;
      });
    return const TerminalEchoState();
  }

  /// Loads the first page of an airport's feed and joins its realtime room.
  Future<void> loadFeed(String airportIata) async {
    state = state.copyWith(isLoading: true, currentAirportIata: airportIata);
    final repo = ref.read(terminalEchoRepositoryProvider);
    final result = await repo.getEchoes(airportIata: airportIata);
    // The user may have switched airports while this feed was loading.
    if (!ref.mounted || state.currentAirportIata != airportIata) return;

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (page) {
        state = state.copyWith(
          isLoading: false,
          echoes: page.echoes,
          nextCursor: page.nextCursor,
        );
        _initSocket(airportIata);
      },
    );
  }

  /// Appends the next page, if there is one and none is loading. Echoes the
  /// socket already prepended aren't repeated.
  Future<void> loadMore() async {
    final airportIata = state.currentAirportIata;
    final cursor = state.nextCursor;
    if (airportIata == null || cursor == null || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);
    final result = await ref
        .read(terminalEchoRepositoryProvider)
        .getEchoes(airportIata: airportIata, cursor: cursor);
    if (!ref.mounted || state.currentAirportIata != airportIata) return;

    result.fold(
      // Keep the cursor: scrolling back down retries.
      (failure) => state = state.copyWith(isLoadingMore: false),
      (page) {
        final known = {for (final e in state.echoes) e.id};
        state = state.copyWith(
          isLoadingMore: false,
          echoes: [
            ...state.echoes,
            ...page.echoes.where((e) => !known.contains(e.id)),
          ],
          nextCursor: page.nextCursor,
        );
      },
    );
  }

  void _initSocket(String airportIata) {
    _socketService?.disconnect();
    _socketService = TerminalEchoSocketService(
      readToken: ref.read(storageServiceProvider).readToken,
      revalidateSession: () =>
          ref.read(authControllerProvider.notifier).refreshAuth(),
    );

    _socketService!.connectAirport(
      airportIata: airportIata,
      onNewEcho: (data) {
        final newEcho = TerminalEchoModel.fromJson(data);
        // Prepend new echo to feed if not already present
        if (!state.echoes.any((e) => e.id == newEcho.id)) {
          state = state.copyWith(echoes: [newEcho, ...state.echoes]);
        }
      },
      onReactionUpdated: (data) {
        // Payload: {terminalEchoId, reactionKey, action, triggeredByUserId}
        // — see gate-closes-api terminal.echo.controller.ts updateReaction.
        final echoId = data['terminalEchoId']?.toString();
        final reactionKey = data['reactionKey']?.toString();
        final action = data['action']?.toString();
        if (echoId == null || reactionKey == null || action == null) return;

        state = state.copyWith(
          echoes: [
            for (final e in state.echoes)
              if (e.id == echoId)
                e.withReactionDelta(reactionKey, action)
              else
                e,
          ],
        );
      },
    );
  }

  /// Posts a new echo and prepends it optimistically. `fileUrl`/`fileName`
  /// are mandatory — see `TerminalEchoRepository.createEcho`.
  Future<bool> postEcho({
    required String textMessage,
    required String airportName,
    required LocationCoordinates coordinates,
    required String fileUrl,
    required String fileName,
    double audioDuration = 0,
    List<double> waveformData = const [],
  }) async {
    final repo = ref.read(terminalEchoRepositoryProvider);
    final result = await repo.createEcho(
      textMessage: textMessage,
      airportName: airportName,
      coordinates: coordinates,
      fileUrl: fileUrl,
      fileName: fileName,
      audioDuration: audioDuration,
      waveformData: waveformData,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
      (created) {
        if (!state.echoes.any((e) => e.id == created.id)) {
          state = state.copyWith(echoes: [created, ...state.echoes]);
        }
        return true;
      },
    );
  }

  /// Sends a reaction update.
  Future<void> react({
    required String echoId,
    required EchoReactionType reaction,
  }) async {
    final repo = ref.read(terminalEchoRepositoryProvider);
    await repo.updateReaction(echoId: echoId, reaction: reaction);
  }

  /// Fire-and-forget listen-count bump — mirrors RN's behavior of not
  /// surfacing a failure here (a missed listen tick isn't worth an error).
  /// The new count shows on every card of this echo (see [ListenCounts]).
  Future<void> incrementListen(String echoId) async {
    final repo = ref.read(terminalEchoRepositoryProvider);
    final result = await repo.incrementListen(echoId);
    if (!ref.mounted) return;
    result.match((_) {}, (count) {
      if (count != null) {
        ref.read(listenCountsProvider.notifier).record(echoId, count);
      }
    });
  }
}

final terminalEchoControllerProvider =
    NotifierProvider<TerminalEchoController, TerminalEchoState>(
  TerminalEchoController.new,
);

/// The airport picked in the feed's search (Expo's `feedLocationOverride`);
/// null means the feed follows the detected airport. Kept app-wide so it
/// survives tab switches, as in Expo.
class FeedAirportOverride extends Notifier<AirportEntity?> {
  @override
  AirportEntity? build() {
    ref.watch(authControllerProvider.select((s) => s.user?.id));
    return null;
  }

  /// Browses [airport]'s feed; picking the [detected] airport clears it.
  void browse(AirportEntity airport, {required AirportEntity? detected}) {
    state = airport.iata == detected?.iata ? null : airport;
  }

  void clear() => state = null;
}

final feedAirportOverrideProvider =
    NotifierProvider<FeedAirportOverride, AirportEntity?>(
  FeedAirportOverride.new,
);
