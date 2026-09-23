import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/services/storage_service.dart';
import 'package:flutter_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_template/features/location/domain/entities/location_coordinates.dart';
import 'package:flutter_template/features/terminal_echo/data/datasources/terminal_echo_socket_service.dart';
import 'package:flutter_template/features/terminal_echo/data/models/terminal_echo_model.dart';
import 'package:flutter_template/features/terminal_echo/data/repositories/terminal_echo_repository_impl.dart';
import 'package:flutter_template/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:flutter_template/features/terminal_echo/domain/repositories/terminal_echo_repository.dart';

// --- Dependency wiring ---

final terminalEchoRepositoryProvider = Provider<TerminalEchoRepository>((ref) {
  return TerminalEchoRepositoryImpl(ref.watch(apiServiceProvider));
});

// --- State ---

class TerminalEchoState extends Equatable {
  const TerminalEchoState({
    this.isLoading = false,
    this.echoes = const [],
    this.currentAirportIata,
    this.error,
  });

  final bool isLoading;
  final List<TerminalEchoEntity> echoes;
  final String? currentAirportIata;
  final String? error;

  TerminalEchoState copyWith({
    bool? isLoading,
    List<TerminalEchoEntity>? echoes,
    String? currentAirportIata,
    String? error,
  }) {
    return TerminalEchoState(
      isLoading: isLoading ?? this.isLoading,
      echoes: echoes ?? this.echoes,
      currentAirportIata: currentAirportIata ?? this.currentAirportIata,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        echoes,
        currentAirportIata,
        error,
      ];
}

// --- Controller ---

class TerminalEchoController extends Notifier<TerminalEchoState> {
  TerminalEchoSocketService? _socketService;

  @override
  TerminalEchoState build() {
    ref.onDispose(() {
      _socketService?.disconnect();
    });
    return const TerminalEchoState();
  }

  /// Loads feed for a given airport and establishes a realtime socket room.
  Future<void> loadFeed(String airportIata) async {
    state = state.copyWith(isLoading: true, currentAirportIata: airportIata);
    final repo = ref.read(terminalEchoRepositoryProvider);
    final result = await repo.getEchoes(airportIata: airportIata);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (echoes) {
        state = state.copyWith(
          isLoading: false,
          echoes: echoes,
        );
        _initSocket(airportIata);
      },
    );
  }

  void _initSocket(String airportIata) {
    final token = ref.read(storageServiceProvider).readUserModel()?.token;
    _socketService?.disconnect();
    _socketService = TerminalEchoSocketService(token: token);

    _socketService!.connect(
      airportIata: airportIata,
      onNewEcho: (data) {
        final newEcho = TerminalEchoModel.fromJson(data);
        // Prepend new echo to feed if not already present
        if (!state.echoes.any((e) => e.id == newEcho.id)) {
          state = state.copyWith(echoes: [newEcho, ...state.echoes]);
        }
      },
      onReactionUpdated: (data) {
        final echoId = (data['terminalEchoId'] ?? data['_id'])?.toString();
        if (echoId == null) return;

        final updatedList = state.echoes.map((e) {
          if (e.id != echoId) return e;

          final reaction = data['reaction']?.toString();
          final direction = data['direction']?.toString();
          final delta = direction == 'decrement' ? -1 : 1;

          switch (reaction) {
            case 'like':
              return e.copyWith(
                countReactLike: (e.countReactLike + delta).clamp(0, 99999),
              );
            case 'love':
              return e.copyWith(
                countReactLove: (e.countReactLove + delta).clamp(0, 99999),
              );
            case 'haha':
              return e.copyWith(
                countReactHaha: (e.countReactHaha + delta).clamp(0, 99999),
              );
            case 'wow':
              return e.copyWith(
                countReactWow: (e.countReactWow + delta).clamp(0, 99999),
              );
            case 'sad':
              return e.copyWith(
                countReactSad: (e.countReactSad + delta).clamp(0, 99999),
              );
            case 'angry':
              return e.copyWith(
                countReactAngry: (e.countReactAngry + delta).clamp(0, 99999),
              );
            default:
              return e;
          }
        }).toList();

        state = state.copyWith(echoes: updatedList);
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
  Future<void> incrementListen(String echoId) async {
    final repo = ref.read(terminalEchoRepositoryProvider);
    await repo.incrementListen(echoId);
  }
}

final terminalEchoControllerProvider =
    NotifierProvider<TerminalEchoController, TerminalEchoState>(
  TerminalEchoController.new,
);
