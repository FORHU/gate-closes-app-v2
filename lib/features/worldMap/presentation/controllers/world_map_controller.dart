import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/location/location_repository_impl.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/worldMap/data/datasources/map_disk_cache.dart';
import 'package:gate_closes/features/worldMap/data/datasources/map_echo_socket.dart';
import 'package:gate_closes/features/worldMap/data/repositories/echo_map_repository_impl.dart';
import 'package:gate_closes/features/worldMap/data/repositories/offer_map_repository_impl.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_boundary_index.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_pin_plan.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_features.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_offer.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/echo_map_repository.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/offer_map_repository.dart';

final echoMapRepositoryProvider = Provider<EchoMapRepository>((ref) {
  return EchoMapRepositoryImpl(ref.watch(apiServiceProvider));
});

final offerMapRepositoryProvider = Provider<OfferMapRepository>((ref) {
  return OfferMapRepositoryImpl(ref.watch(apiServiceProvider));
});

/// [WorldMapState.copyWith] value meaning "leave unchanged", so `null` can
/// still clear a nullable field.
const _keep = Object();

class WorldMapState extends Equatable {
  const WorldMapState({
    this.isLoading = false,
    this.airports = const [],
    this.airportBoundariesGeoJson,
    this.echoNodes = const [],
    this.pinMode = MapPinMode.pins,
    this.airportCounts = const [],
    this.selectedAirport,
    this.userLocation,
    this.isFetchingPins = false,
    this.offerPins = const [],
    this.offerCard,
    this.error,
  });

  final bool isLoading;
  final List<AirportEntity> airports;
  final Map<String, dynamic>? airportBoundariesGeoJson;
  final List<TerminalEchoMapNodeEntity> echoNodes;

  /// Pins ([echoNodes]) when zoomed in on airports, or one bubble per
  /// airport ([airportCounts]) when zoomed out.
  final MapPinMode pinMode;
  final List<AirportEchoCount> airportCounts;
  final AirportEntity? selectedAirport;

  /// Where the user is, once resolved; the map opens centered here.
  final LocationCoordinates? userLocation;

  /// A view's pins or counts are loading (drives the slow-connection banner).
  final bool isFetchingPins;

  /// Offers (ads, vouchers) of the airports in view, when zoomed in: pins at
  /// their spots, and one card for the airport nearest the view center.
  /// Empty when zoomed out or when offers couldn't load: never in the way
  /// of the echo pins.
  final List<MapOffer> offerPins;
  final MapOffer? offerCard;
  final String? error;

  WorldMapState copyWith({
    bool? isLoading,
    List<AirportEntity>? airports,
    Map<String, dynamic>? airportBoundariesGeoJson,
    List<TerminalEchoMapNodeEntity>? echoNodes,
    MapPinMode? pinMode,
    List<AirportEchoCount>? airportCounts,
    AirportEntity? selectedAirport,
    LocationCoordinates? userLocation,
    bool? isFetchingPins,
    List<MapOffer>? offerPins,
    Object? offerCard = _keep,
    String? error,
  }) =>
      WorldMapState(
        isLoading: isLoading ?? this.isLoading,
        airports: airports ?? this.airports,
        airportBoundariesGeoJson:
            airportBoundariesGeoJson ?? this.airportBoundariesGeoJson,
        echoNodes: echoNodes ?? this.echoNodes,
        pinMode: pinMode ?? this.pinMode,
        airportCounts: airportCounts ?? this.airportCounts,
        selectedAirport: selectedAirport ?? this.selectedAirport,
        userLocation: userLocation ?? this.userLocation,
        isFetchingPins: isFetchingPins ?? this.isFetchingPins,
        offerPins: offerPins ?? this.offerPins,
        offerCard: identical(offerCard, _keep)
            ? this.offerCard
            : offerCard as MapOffer?,
        error: error,
      );

  @override
  List<Object?> get props => [
        isLoading,
        airports,
        airportBoundariesGeoJson,
        echoNodes,
        pinMode,
        airportCounts,
        selectedAirport,
        userLocation,
        isFetchingPins,
        offerPins,
        offerCard,
        error,
      ];
}

class WorldMapController extends Notifier<WorldMapState> {
  /// Every airport polygon. Kept out of [state] (only the on-screen subset
  /// goes there) so it isn't deep-compared on every state change or pushed
  /// to Mapbox whole — see [AirportBoundaryIndex].
  AirportBoundaryIndex _boundaries = AirportBoundaryIndex.empty;

  /// Counts view refreshes, so a slow answer for an old view can't
  /// overwrite a newer one.
  int _viewRequest = 0;

  /// Pins per airport code, fetched once and then kept fresh by the
  /// airport's Socket.IO room while it's on screen.
  final Map<String, List<TerminalEchoMapNodeEntity>> _airportPins = {};

  /// Airports whose pins are on screen (and whose rooms are joined).
  List<String> _shownAirports = const [];

  List<AirportEchoCount> _counts = const [];
  DateTime? _countsAt;

  /// Requests in flight, shared: the camera fires several changes while
  /// the map settles, and each must not start its own identical request.
  Future<void>? _countsLoading;
  final Map<String, Future<bool>> _pinsLoading = {};
  MapEchoSocket? _socket;

  /// Offers per airport and when they were fetched. Pin spots are fixed per
  /// traveler for the day, so a short cache is enough.
  final Map<String, AirportOffers> _airportOffers = {};
  final Map<String, DateTime> _offersAt = {};
  final Map<String, Future<void>> _offersLoading = {};

  /// Offers older than this are fetched again when their airport is shown.
  static const offersMaxAge = Duration(minutes: 10);

  /// Counts older than this are fetched again on the next view change.
  static const countsMaxAge = Duration(minutes: 1);

  static const _boundariesCache = 'boundaries';
  static const _pinsCache = 'pins';
  static const _countsCache = 'counts';
  static const _lastLocationKey = 'map_last_location';

  /// A remembered location this recent centers the map before GPS answers
  /// (Expo `MapShellLocationTracker`: 15 minutes).
  static const lastLocationMaxAge = Duration(minutes: 15);

  @override
  WorldMapState build() {
    ref.onDispose(() => _socket?.dispose());
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

    // 2. Echo pins: show the cached set now. Live pins and counts are
    //    fetched for the view once the camera settles (refreshForView).
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

  /// Loads what the view shows: per-airport counts when zoomed out, or
  /// the pins of the airports in view when zoomed in (see [AirportPinPlan]).
  Future<void> refreshForView({
    required double west,
    required double south,
    required double east,
    required double north,
    required double zoom,
    required double centerLng,
    required double centerLat,
  }) async {
    final request = ++_viewRequest;
    state = state.copyWith(isFetchingPins: true);
    await _ensureCounts();
    if (request != _viewRequest) return;
    final plan = AirportPinPlan.forView(
      counts: _counts,
      west: west,
      south: south,
      east: east,
      north: north,
      zoom: zoom,
      centerLng: centerLng,
      centerLat: centerLat,
    );

    if (plan.mode == MapPinMode.counts) {
      _showAirports(const []);
      state = state.copyWith(
        isFetchingPins: false,
        pinMode: MapPinMode.counts,
        airportCounts: _counts,
        offerPins: const [],
        offerCard: null,
      );
      return;
    }

    final missing = plan.airports.where((a) => !_airportPins.containsKey(a));
    final loaded = await Future.wait(missing.map(_loadAirportPins));
    // A newer view was requested meanwhile; its answer wins.
    if (request != _viewRequest) return;
    _showAirports(plan.airports);
    var nodes = _pinsFor(plan.airports);
    if (loaded.contains(false) && nodes.isEmpty) {
      // Offline: the pins of the last successful load.
      nodes = await _cachedPins() ?? state.echoNodes;
      if (request != _viewRequest) return;
    } else if (!loaded.contains(false)) {
      unawaited(
        ref
            .read(mapDiskCacheProvider)
            .write(_pinsCache, EchoMapFeatures.collection(nodes)),
      );
    }
    state = state.copyWith(
      isFetchingPins: false,
      pinMode: MapPinMode.pins,
      echoNodes: nodes,
    );
    // After the echo pins, never before them: offers are extra.
    unawaited(_refreshOffers(plan.airports, request));
  }

  /// Loads the shown airports' offers (missing or stale ones) and shows
  /// their pins and the nearest airport's card. Failures leave offers out.
  Future<void> _refreshOffers(List<String> airports, int request) async {
    final now = DateTime.now();
    final stale = airports.where((a) {
      final at = _offersAt[a];
      return at == null || now.difference(at) > offersMaxAge;
    });
    await Future.wait(stale.map(_loadAirportOffers));
    // Offers load after the pins, so the map may have closed meanwhile.
    if (!ref.mounted) return;
    if (request != _viewRequest || state.pinMode != MapPinMode.pins) return;
    final offers = airports.map((a) => _airportOffers[a]).nonNulls.toList();
    state = state.copyWith(
      offerPins: [for (final o in offers) ...o.pins],
      // [airports] is nearest-first, so this is the nearest airport's card.
      offerCard: offers.map((o) => o.card).nonNulls.firstOrNull,
    );
  }

  Future<void> _loadAirportOffers(String airportIata) =>
      _offersLoading[airportIata] ??= _fetchAirportOffers(airportIata);

  Future<void> _fetchAirportOffers(String airportIata) async {
    try {
      final result = await ref
          .read(offerMapRepositoryProvider)
          .getAirportOffers(airportIata);
      result.match((_) {}, (offers) {
        _airportOffers[airportIata] = offers;
        _offersAt[airportIata] = DateTime.now();
      });
    } finally {
      _offersLoading.removeWhere((key, _) => key == airportIata);
    }
  }

  /// A traveler saw or opened [offer]; for the offer's stats only.
  void trackOffer(MapOffer offer, OfferEvent event) => unawaited(
        ref
            .read(offerMapRepositoryProvider)
            .track(offer.id, event, airportIata: offer.airportIata),
      );

  /// Claims [offer] (a voucher...): its reward, or why it was refused.
  Future<Either<Failure, OfferReward>> claimOffer(MapOffer offer) => ref
      .read(offerMapRepositoryProvider)
      .claim(offer.id, airportIata: offer.airportIata);

  /// Fetches the counts when missing or older than [countsMaxAge]; the
  /// cached counts when offline.
  Future<void> _ensureCounts() {
    final at = _countsAt;
    if (at != null && DateTime.now().difference(at) < countsMaxAge) {
      return Future.value();
    }
    return _countsLoading ??= _fetchCounts().whenComplete(() {
      _countsLoading = null;
    });
  }

  Future<void> _fetchCounts() async {
    final cache = ref.read(mapDiskCacheProvider);
    final result = await ref.read(echoMapRepositoryProvider).getAirportCounts();
    await result.fold(
      (_) async {
        if (_counts.isEmpty) _counts = await _cachedCounts();
      },
      (counts) async {
        _counts = counts;
        _countsAt = DateTime.now();
        unawaited(
          cache.write(_countsCache, AirportEchoCount.collection(counts)),
        );
      },
    );
  }

  Future<List<AirportEchoCount>> _cachedCounts() async {
    final features =
        (await ref.read(mapDiskCacheProvider).read(_countsCache))?['features'];
    if (features is! List) return const [];
    return features
        .whereType<Map<dynamic, dynamic>>()
        .map((f) => AirportEchoCount.fromGeoJsonFeature(f.cast()))
        .whereType<AirportEchoCount>()
        .toList();
  }

  /// True when the airport's pins were fetched (and are now cached).
  Future<bool> _loadAirportPins(String airportIata) =>
      _pinsLoading[airportIata] ??= _fetchAirportPins(airportIata);

  Future<bool> _fetchAirportPins(String airportIata) async {
    try {
      final result = await ref
          .read(echoMapRepositoryProvider)
          .getAirportNodes(airportIata);
      return result.fold((_) => false, (nodes) {
        _airportPins[airportIata] = nodes;
        return true;
      });
    } finally {
      _pinsLoading.removeWhere((key, _) => key == airportIata);
    }
  }

  List<TerminalEchoMapNodeEntity> _pinsFor(List<String> airports) => [
        for (final a in airports) ...?_airportPins[a],
      ];

  /// Joins the rooms of the airports on screen and leaves the others.
  void _showAirports(List<String> airports) {
    _shownAirports = airports;
    if (airports.isEmpty && _socket == null) return;
    _socket ??= ref.read(mapEchoSocketFactoryProvider)(_onAirportChanged);
    _socket!.watch(airports.toSet());
  }

  /// A new echo at [airportIata] (or somewhere, when unknown): drop the
  /// stale pins and counts, and reload what's on screen.
  Future<void> _onAirportChanged(String? airportIata) async {
    _countsAt = null;
    final changed = airportIata == null
        ? List.of(_shownAirports)
        : [if (_shownAirports.contains(airportIata)) airportIata];
    if (airportIata == null) {
      _airportPins.clear();
    } else {
      _airportPins.remove(airportIata);
    }
    final request = _viewRequest;
    if (state.pinMode == MapPinMode.counts) {
      await _ensureCounts();
      if (request == _viewRequest) {
        state = state.copyWith(airportCounts: _counts);
      }
      return;
    }
    if (changed.isEmpty) return;
    await Future.wait(changed.map(_loadAirportPins));
    if (request != _viewRequest) return;
    state = state.copyWith(echoNodes: _pinsFor(_shownAirports));
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
