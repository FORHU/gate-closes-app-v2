import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/features/airport/domain/entities/airport_entity.dart';
import 'package:flutter_template/features/airport/presentation/controllers/airport_controller.dart';

// --- State ---

class WorldMapState extends Equatable {
  const WorldMapState({
    this.isLoading = false,
    this.airports = const [],
    this.error,
  });

  final bool isLoading;
  final List<AirportEntity> airports;
  final String? error;

  WorldMapState copyWith({
    bool? isLoading,
    List<AirportEntity>? airports,
    String? error,
  }) =>
      WorldMapState(
        isLoading: isLoading ?? this.isLoading,
        airports: airports ?? this.airports,
        error: error,
      );

  @override
  List<Object?> get props => [isLoading, airports, error];
}

// --- Controller ---

/// Drives the "nearby airports" list — device location (via
/// [locationRepositoryProvider]) + `GET /airport/nearby` (via
/// [airportRepositoryProvider]). Replace/extend once a real map SDK
/// (`flutter_map`, `mapbox_maps_flutter`) is wired in.
class WorldMapController extends Notifier<WorldMapState> {
  @override
  WorldMapState build() {
    unawaited(Future.microtask(fetchNearbyAirports));
    return const WorldMapState(isLoading: true);
  }

  Future<void> fetchNearbyAirports() async {
    state = state.copyWith(isLoading: true);

    final locationRepo = ref.read(locationRepositoryProvider);
    final airportRepo = ref.read(airportRepositoryProvider);

    final locationResult = await locationRepo.getCurrentLocation();

    await locationResult.fold(
      (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (coordinates) async {
        final airportsResult = await airportRepo.findNearby(coordinates);
        airportsResult.fold(
          (failure) =>
              state = state.copyWith(isLoading: false, error: failure.message),
          (airports) => state = WorldMapState(airports: airports),
        );
      },
    );
  }
}

final worldMapControllerProvider =
    NotifierProvider<WorldMapController, WorldMapState>(
  WorldMapController.new,
);
