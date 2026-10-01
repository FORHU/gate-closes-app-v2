import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/location/location_repository_impl.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/worldMap/data/datasources/map_disk_cache.dart';
import 'package:gate_closes/features/worldMap/data/repositories/echo_map_repository_impl.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_boundary_index.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_features.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/echo_map_repository.dart';

final echoMapRepositoryProvider = Provider<EchoMapRepository>((ref) {
  return EchoMapRepositoryImpl(ref.watch(apiServiceProvider));
});

class WorldMapState extends Equatable {
  const WorldMapState({
    this.isLoading = false,
    this.airports = const [],
    this.airportBoundariesGeoJson,
    this.echoNodes = const [],
    this.selectedAirport,
    this.userLocation,
    this.isFetchingPins = false,
    this.error,
  });

  final bool isLoading;
  final List<AirportEntity> airports;
  final Map<String, dynamic>? airportBoundariesGeoJson;
  final List<TerminalEchoMapNodeEntity> echoNodes;
  final AirportEntity? selectedAirport;

  /// Where the user is, once resolved; the map opens centered here.
  final LocationCoordinates? userLocation;

  /// A viewport pin fetch is in flight (drives the slow-connection banner).
  final bool isFetchingPins;
  final String? error;

  WorldMapState copyWith({
    bool? isLoading,
    List<AirportEntity>? airports,
    Map<String, dynamic>? airportBoundariesGeoJson,
    List<TerminalEchoMapNodeEntity>? echoNodes,
    AirportEntity? selectedAirport,
    LocationCoordinates? userLocation,
    bool? isFetchingPins,
    String? error,
  }) =>
      WorldMapState(
        isLoading: isLoading ?? this.isLoading,
        airports: airports ?? this.airports,
        airportBoundariesGeoJson:
            airportBoundariesGeoJson ?? this.airportBoundariesGeoJson,
        echoNodes: echoNodes ?? this.echoNodes,
        selectedAirport: selectedAirport ?? this.selectedAirport,
        userLocation: userLocation ?? this.userLocation,
        isFetchingPins: isFetchingPins ?? this.isFetchingPins,
        error: error,
      );

  @override
  List<Object?> get props => [
        isLoading,
        airports,
        airportBoundariesGeoJson,
        echoNodes,
        selectedAirport,
        userLocation,
        isFetchingPins,
        error,
      ];
}

class WorldMapController extends Notifier<WorldMapState> {
  /// Every airport polygon. Kept out of [state] (only the on-screen subset
  /// goes there) so it isn't deep-compared on every state change or pushed
  /// to Mapbox whole — see [AirportBoundaryIndex].
  AirportBoundaryIndex _boundaries = AirportBoundaryIndex.empty;

  /// Counts viewport pin fetches, so a slow answer for an old viewport
  /// can't overwrite a newer one.
  int _pinRequest = 0;

  static const _boundariesCache = 'boundaries';
  static const _pinsCache = 'pins';
  static const _lastLocationKey = 'map_last_location';

  /// A remembered location this recent centers the map before GPS answers
  /// (Expo `MapShellLocationTracker`: 15 minutes).
  static const lastLocationMaxAge = Duration(minutes: 15);

  @override
  WorldMapState build() {
    unawaited(Future.microtask(initMapData));
    return const WorldMapState(isLoading: true);
  }

  Future<void> initMapData() async {
    final remembered = _readLastLocation();
    state = state.copyWith(isLoading: true, userLocation: remembered);

    final locationRepo = ref.read(locationRepositoryProvider);
    final airportRepo = ref.read(airportRepositoryProvider);
    final cache = ref.read(mapDiskCacheProvider);

    // 1. Airport boundaries — the disk copy when the network fails.
    final boundaryResult = await airportRepo.getAirportGeoJson();
    final boundaries = await boundaryResult.fold(
      (_) => cache.read(_boundariesCache),
      (data) async {
        unawaited(cache.write(_boundariesCache, data));
        return data;
      },
    );
    _boundaries = AirportBoundaryIndex.fromGeoJson(boundaries);

    // 2. Echo pins: show the cached set now. Live pins are fetched for the
    //    visible area once the camera settles — never an unbounded request.
    final echoNodes = await _cachedPins();

    // 3. Resolve user location and nearby airports
    final locationResult = await locationRepo.getCurrentLocation();
    await locationResult.fold(
      (failure) async {
        state = state.copyWith(
          isLoading: false,
          echoNodes: echoNodes,
          error: failure.message,
        );
      },
      (coordinates) async {
        updateUserLocation(coordinates);
        final airportsResult = await airportRepo.findNearby(coordinates);
        airportsResult.fold(
          (failure) => state = state.copyWith(
            isLoading: false,
            echoNodes: echoNodes,
            error: failure.message,
          ),
          (airports) {
            state = state.copyWith(
              isLoading: false,
              airports: airports,
              selectedAirport: airports.isNotEmpty ? airports.first : null,
              echoNodes: echoNodes,
            );
          },
        );
      },
    );
  }

  Future<void> fetchEchoNodesForBounds({
    required double west,
    required double south,
    required double east,
    required double north,
  }) async {
    final request = ++_pinRequest;
    state = state.copyWith(isFetchingPins: true);
    final nodes = await _loadPins(
      west: west,
      south: south,
      east: east,
      north: north,
    );
    // A newer viewport was requested meanwhile; its answer wins.
    if (request != _pinRequest) return;
    state = state.copyWith(isFetchingPins: false, echoNodes: nodes);
  }

  /// Pins from the API, cached on success; the cached set when offline.
  Future<List<TerminalEchoMapNodeEntity>> _loadPins({
    double? west,
    double? south,
    double? east,
    double? north,
  }) async {
    final cache = ref.read(mapDiskCacheProvider);
    final result = await ref.read(echoMapRepositoryProvider).getNodes(
          west: west,
          south: south,
          east: east,
          north: north,
        );
    return result.fold(
      (_) async => await _cachedPins() ?? state.echoNodes,
      (nodes) {
        unawaited(cache.write(_pinsCache, EchoMapFeatures.collection(nodes)));
        return nodes;
      },
    );
  }

  Future<List<TerminalEchoMapNodeEntity>?> _cachedPins() async {
    final features =
        (await ref.read(mapDiskCacheProvider).read(_pinsCache))?['features'];
    if (features is! List) return null;
    return [
      for (final f in features.whereType<Map<dynamic, dynamic>>())
        TerminalEchoMapNodeEntity.fromGeoJsonFeature(f.cast<String, dynamic>()),
    ];
  }

  /// A new position from GPS or the live tracker. Remembered on the device
  /// only at the same ~110 m precision the API ever sees.
  void updateUserLocation(LocationCoordinates location) {
    state = state.copyWith(userLocation: location);
    final coarse = location.quantize();
    unawaited(
      ref.read(storageServiceProvider).setString(
            _lastLocationKey,
            jsonEncode({
              'lat': coarse.latitude,
              'lng': coarse.longitude,
              'at': DateTime.now().millisecondsSinceEpoch,
            }),
          ),
    );
  }

  LocationCoordinates? _readLastLocation() {
    try {
      final raw = ref.read(storageServiceProvider).getString(_lastLocationKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.fromMillisecondsSinceEpoch(json['at'] as int);
      if (DateTime.now().difference(at) > lastLocationMaxAge) return null;
      return LocationCoordinates(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
      );
    } on Object catch (_) {
      return null;
    }
  }

  /// Shows the airport boundaries overlapping the visible map (none when
  /// zoomed out past [AirportBoundaryIndex.minZoom]).
  void updateVisibleBoundaries({
    required double west,
    required double south,
    required double east,
    required double north,
    required double zoom,
  }) {
    state = state.copyWith(
      airportBoundariesGeoJson: _boundaries.visible(
        west: west,
        south: south,
        east: east,
        north: north,
        zoom: zoom,
      ),
    );
  }

  void selectAirport(AirportEntity airport) {
    state = state.copyWith(selectedAirport: airport);
  }
}

final worldMapControllerProvider =
    NotifierProvider<WorldMapController, WorldMapState>(
  WorldMapController.new,
);
