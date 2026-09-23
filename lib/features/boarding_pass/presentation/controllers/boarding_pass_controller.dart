import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_template/features/boarding_pass/data/repositories/boarding_pass_repository_impl.dart';
import 'package:flutter_template/features/boarding_pass/domain/entities/boarding_pass_entity.dart';
import 'package:flutter_template/features/boarding_pass/domain/parsers/bcbp_parser.dart';
import 'package:flutter_template/features/boarding_pass/domain/repositories/boarding_pass_repository.dart';

// --- Dependency wiring ---

final boardingPassRepositoryProvider = Provider<BoardingPassRepository>((ref) {
  return BoardingPassRepositoryImpl(ref.watch(apiServiceProvider));
});

// --- State ---

class BoardingPassState extends Equatable {
  const BoardingPassState({
    this.isLoading = false,
    this.activePass,
    this.lastParsedPass,
    this.error,
    this.successMessage,
  });

  final bool isLoading;
  final BoardingPassEntity? activePass;
  final BoardingPassEntity? lastParsedPass;
  final String? error;
  final String? successMessage;

  bool get hasActivePass => activePass != null;

  BoardingPassState copyWith({
    bool? isLoading,
    BoardingPassEntity? activePass,
    BoardingPassEntity? lastParsedPass,
    String? error,
    String? successMessage,
  }) {
    return BoardingPassState(
      isLoading: isLoading ?? this.isLoading,
      activePass: activePass ?? this.activePass,
      lastParsedPass: lastParsedPass ?? this.lastParsedPass,
      error: error,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        activePass,
        lastParsedPass,
        error,
        successMessage,
      ];
}

// --- Controller ---

class BoardingPassController extends Notifier<BoardingPassState> {
  @override
  BoardingPassState build() {
    return const BoardingPassState();
  }

  /// Parses raw barcode text scanned by camera.
  bool parseBarcode(String rawBarcode) {
    final parsed = BcbpParser.parse(rawBarcode);
    if (parsed == null) {
      state = state.copyWith(
        error: 'Invalid or unsupported boarding pass barcode format.',
      );
      return false;
    }

    state = state.copyWith(lastParsedPass: parsed);
    return true;
  }

  /// Submits the boarding pass to the backend.
  Future<bool> registerPass({
    required BoardingPassEntity pass,
    required DateTime departureDateTime,
    required DateTime returnDateTime,
    DateTime? arrivalDateTime,
  }) async {
    state = state.copyWith(isLoading: true);
    final repo = ref.read(boardingPassRepositoryProvider);

    final result = await repo.registerBoardingPass(
      boardingPass: pass,
      departureDateTime: departureDateTime,
      returnDateTime: returnDateTime,
      arrivalDateTime: arrivalDateTime,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
        return false;
      },
      (msg) {
        state = state.copyWith(
          isLoading: false,
          activePass: pass,
          successMessage: msg,
        );
        return true;
      },
    );
  }

  /// Loads active boarding pass from the backend.
  Future<void> fetchActivePass() async {
    state = state.copyWith(isLoading: true);
    final repo = ref.read(boardingPassRepositoryProvider);
    final result = await repo.getActiveBoardingPass();

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (pass) => state = state.copyWith(
        isLoading: false,
        activePass: pass,
      ),
    );
  }
}

final boardingPassControllerProvider =
    NotifierProvider<BoardingPassController, BoardingPassState>(
  BoardingPassController.new,
);
