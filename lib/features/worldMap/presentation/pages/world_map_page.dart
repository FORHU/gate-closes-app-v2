import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/location/location_repository_impl.dart';
import 'package:gate_closes/core/services/connectivity_service.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_features.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/map_lighting_controller.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/map_render_guard.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/world_map_controller.dart';
import 'package:gate_closes/features/worldMap/presentation/map_badges.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/map_bottom_nav.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

const Map<String, Object> _kEmptyFeatureCollection = {
  'type': 'FeatureCollection',
  'features': <Object>[],
};

const _kBoundarySource = 'airport-boundaries-source';
const _kHeatmapSource = 'echo-heatmap-source';
const _kPinsSource = 'echo-symbols-source';
const _kClusterLayer = 'echo-clusters';
const _kPinLayer = 'echo-symbols';

/// Pin badge size, and the size of the one whose card is open (Expo).
const double _kPinSize = 0.72;
const double _kSelectedPinSize = 0.85;

/// 32-bit ARM Android phones are low-end (small RAM, weak GPUs such as
/// PowerVR GE8320); terrain and 3D buildings stop the map opening there.
final bool _kLiteMap = Abi.current() == Abi.androidArm;

/// How long the map may take to render before this phone is treated as
/// unable to show it, and how long it must then stay up to count as working.
const Duration _kMapLoadTimeout = Duration(seconds: 25);
const Duration _kMapStableFor = Duration(seconds: 5);

/// At or below this zoom, rotation is locked (Expo's gesture lock).
const double _kGestureLockZoom = 3.5;

/// Expo map-shell zoom levels.
const double _kMinZoom = 2.8;
const double _kUserZoom = 14;
const double _kRecenterZoom = 16;
const double _kAirportZoom = 13;

/// The map tab — home of the app, as in the Expo map shell
/// (`app/(tabs)/map/index.tsx`): a full-screen Mapbox canvas with airport
/// boundaries, an activity heatmap and clustered echo pins, a search pill on
/// top and a recenter button above the navigation bar.
///
/// Tapping a pin opens its card (`/map/echo/:id`); tapping a cluster zooms
/// in. Architecture notes: `docs/MAP_EXPO_PARITY.md`.
class WorldMapPage extends ConsumerStatefulWidget {
  const WorldMapPage({super.key});

  @override
  ConsumerState<WorldMapPage> createState() => _WorldMapPageState();
}

class _WorldMapPageState extends ConsumerState<WorldMapPage> {
  MapboxMap? _map;
  bool _styleReady = false;
  Timer? _boundsDebounce;

  /// Re-evaluates realtime lighting every minute (Expo does the same).
  Timer? _lightingTicker;

  /// Live position (Expo `MapShellLocationTracker`), started after the
  /// first fix so location permission has already been asked for.
  StreamSubscription<LocationCoordinates>? _positionSub;

  /// Where the airport was last re-detected; moving 250 m re-checks it.
  LocationCoordinates? _lastDetectedAt;
  static const _redetectDistanceMeters = 250;

  /// Set when a map load has been running for 3 s (Expo "SLOW CONNECTION").
  Timer? _slowTimer;
  bool _slow = false;

  /// Follow-the-user mode (Expo's `isFollowingUser`): on until the user pans.
  bool _following = true;
  bool _centeredOnUser = false;

  /// Crash-safe check that this phone can render the map.
  late final MapRenderGuard _guard;

  /// True once the guard's marker is saved and the map may be created.
  bool _armed = false;

  /// Set once the map has rendered, or has been reported as failing.
  bool _renderSettled = false;
  Timer? _loadTimeout;

  @override
  void initState() {
    super.initState();
    _guard = ref.read(mapRenderGuardProvider.notifier);
    _lightingTicker = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
    unawaited(Future.microtask(_armMap));
  }

  /// Saves the guard's marker, then creates the map.
  Future<void> _armMap() async {
    if (ref.read(mapRenderGuardProvider) != MapRenderStatus.tryMap) return;
    await _guard.starting();
    if (!mounted) return;
    setState(() {
      _armed = true;
      _renderSettled = false;
    });
    _loadTimeout?.cancel();
    _loadTimeout = Timer(_kMapLoadTimeout, () {
      // Offline, the map can't load anyway; that's not the phone's fault.
      if (!mounted || _renderSettled) return;
      if (ref.read(isOfflineProvider).value ?? false) return;
      _renderSettled = true;
      _map = null;
      _styleReady = false;
      _guard.failed();
    });
  }

  Future<void> _retryMap() async {
    await _guard.retry();
    await _armMap();
  }

  @override
  void dispose() {
    _boundsDebounce?.cancel();
    _lightingTicker?.cancel();
    _slowTimer?.cancel();
    _loadTimeout?.cancel();
    unawaited(_positionSub?.cancel());
    // Left the page before the map finished: not a crash, so don't let the
    // marker flag this phone on the next launch.
    if (_armed && !_renderSettled) unawaited(_guard.loaded());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WorldMapState>(worldMapControllerProvider, _onStateChanged);
    final state = ref.watch(worldMapControllerProvider);
    final lighting =
        ref.watch(mapLightingControllerProvider).presetAt(DateTime.now());
    final colors = context.colors;
    final offline = ref.watch(isOfflineProvider).value ?? false;
    final navClearance =
        MapBottomNav.barHeight + MediaQuery.paddingOf(context).bottom;

    if (ref.watch(mapRenderGuardProvider) == MapRenderStatus.unsupported) {
      return _MapUnsupportedNotice(
        onRetry: () => unawaited(_retryMap()),
        onOpenFeed: () => context.go(RouteNames.feed),
      );
    }
    if (!_armed) return const ColoredBox(color: Colors.black);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey('world-map-widget'),
              styleUri: MapboxStyles.DARK,
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,
              onMapIdleListener: _onMapIdle,
              onScrollListener: (_) => _stopFollowing(),
            ),
          ),
          // Map Lighting: Expo's time-of-day atmosphere tint.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(seconds: 1),
                color: lighting.tint,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Column(
                children: [
                  _SearchPill(onTap: _openAirportSearch),
                  if (offline || _slow)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: _ConnectivityBanner(offline: offline),
                    ),
                  if (state.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: colors.accent,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (state.userLocation != null)
            Positioned(
              right: AppSpacing.md,
              bottom: navClearance + AppSpacing.md,
              child: _MapFab(
                tooltip: 'Recenter map to your location',
                icon: _following
                    ? Icons.my_location_rounded
                    : Icons.location_searching_rounded,
                onPressed: _recenterToUser,
              ),
            ),
        ],
      ),
    );
  }

  // --- State → map --------------------------------------------------------

  void _onStateChanged(WorldMapState? previous, WorldMapState next) {
    _trackSlowLoading(next.isLoading || next.isFetchingPins);
    final loaded = previous?.isLoading == true && !next.isLoading;
    if (loaded && next.userLocation != null && _positionSub == null) {
      _startTracking();
    }
    if (!identical(
      previous?.airportBoundariesGeoJson,
      next.airportBoundariesGeoJson,
    )) {
      unawaited(
        _setSourceData(_kBoundarySource, next.airportBoundariesGeoJson),
      );
    }
    if (previous?.echoNodes != next.echoNodes) unawaited(_syncPins());
    if (next.userLocation != null && !_centeredOnUser) {
      _centerOnUser(next.userLocation!, animated: false);
    } else if (previous?.selectedAirport != next.selectedAirport &&
        next.selectedAirport != null &&
        next.userLocation == null) {
      _flyToAirport(next.selectedAirport!);
    }
  }

  Future<void> _setSourceData(String id, Map<String, dynamic>? data) async {
    final map = _map;
    if (map == null || !_styleReady) return;
    // Payloads stay small: pins are fetched per viewport and boundaries are
    // limited to what's on screen (AirportBoundaryIndex) — the full
    // collection once ran Android out of memory in this bridge call.
    await map.style.setStyleSourceProperty(
      id,
      'data',
      jsonEncode(data ?? _kEmptyFeatureCollection),
    );
  }

  Future<void> _syncPins() async {
    final pins = EchoMapFeatures.collection(
      ref.read(worldMapControllerProvider).echoNodes,
    );
    await _setSourceData(_kPinsSource, pins);
    await _setSourceData(_kHeatmapSource, pins);
  }

  // --- Map setup -----------------------------------------------------------

  void _onMapCreated(MapboxMap map) {
    _map = map;
    // Start on the user if their location arrived before the map did;
    // otherwise zoomed out (Expo's minimum) until it arrives.
    final userLocation = ref.read(worldMapControllerProvider).userLocation;
    if (userLocation != null) {
      _centerOnUser(userLocation, animated: false);
    } else {
      unawaited(map.setCamera(CameraOptions(zoom: _kMinZoom)));
    }
    // Expo keeps the map flat and locks rotation when zoomed far out.
    unawaited(
      map.gestures.updateSettings(
        GesturesSettings(pitchEnabled: false, rotateEnabled: false),
      ),
    );
    unawaited(
      map.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: const Color(0xFF4A9DFF).toARGB32(),
        ),
      ),
    );
    map
      ..addInteraction(
        TapInteraction(
          FeaturesetDescriptor(layerId: _kClusterLayer),
          (feature, _) => unawaited(_onClusterTap(feature)),
        ),
        interactionID: 'tap-echo-clusters',
      )
      ..addInteraction(
        TapInteraction(
          FeaturesetDescriptor(layerId: _kPinLayer),
          (feature, _) => _onPinTap(feature),
        ),
        interactionID: 'tap-echo-pins',
      );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null) return;
    final style = map.style;
    final empty = jsonEncode(_kEmptyFeatureCollection);

    // Globe when zoomed out, as Expo (its custom atmosphere colors have no
    // equivalent in this plugin; Mapbox's default atmosphere is used).
    await style.setProjection(
      StyleProjection(name: StyleProjectionName.globe),
    );
    await MapBadges.addTo(style);
    // The theme is decoration: if any part fails (a tileset or a GPU without
    // terrain support), the boundaries and pins must still load.
    try {
      await _addMapTheme(style);
    } on Object catch (e) {
      debugPrint('Map theme skipped: $e');
    }

    // Airport boundaries — fill, glow and outline, as AirportBoundariesLayer.
    await style.addSource(GeoJsonSource(id: _kBoundarySource, data: empty));
    await style.addLayer(
      FillLayer(
        id: 'airport-boundaries-fill',
        sourceId: _kBoundarySource,
        fillColor: const Color(0xFF7F8792).toARGB32(),
        fillOpacity: 0.16,
      ),
    );
    await style.addLayer(
      LineLayer(
        id: 'airport-boundaries-outline-glow',
        sourceId: _kBoundarySource,
        lineColor: const Color(0xFF7F8792).toARGB32(),
        lineOpacity: 0.34,
        lineWidth: 6,
      ),
    );
    await style.addLayer(
      LineLayer(
        id: 'airport-boundaries-outline',
        sourceId: _kBoundarySource,
        lineColor: const Color(0xFFC4CBD4).toARGB32(),
        lineWidth: 1.5,
      ),
    );

    // Activity heatmap under the pins (TerminalMapNodesLayer).
    await style.addSource(GeoJsonSource(id: _kHeatmapSource, data: empty));
    await style.addLayer(
      HeatmapLayer(
        id: 'echo-heatmap',
        sourceId: _kHeatmapSource,
        heatmapWeightExpression: _heatmapWeight,
        heatmapIntensityExpression: _heatmapIntensity,
        heatmapRadiusExpression: _heatmapRadius,
        heatmapOpacityExpression: _heatmapOpacity,
        heatmapColorExpression: _heatmapColor,
      ),
    );

    // Clustered pins with per-type badges.
    await style.addSource(
      GeoJsonSource(
        id: _kPinsSource,
        data: empty,
        cluster: true,
        clusterRadius: 45,
        clusterMaxZoom: 15,
      ),
    );
    await style.addLayer(
      SymbolLayer(
        id: _kClusterLayer,
        sourceId: _kPinsSource,
        filter: ['has', 'point_count'],
        iconImage: MapBadges.cluster,
        iconSize: 0.72,
        iconAllowOverlap: true,
        textFieldExpression: ['get', 'point_count_abbreviated'],
        textSize: 12,
        textColor: const Color(0xFF060606).toARGB32(),
        textHaloColor: Colors.white.withValues(alpha: 0.9).toARGB32(),
        textHaloWidth: 1.2,
        textAllowOverlap: true,
      ),
    );
    await style.addLayer(
      SymbolLayer(
        id: _kPinLayer,
        sourceId: _kPinsSource,
        filter: [
          '!',
          ['has', 'point_count'],
        ],
        iconImageExpression: [
          'match',
          ['get', 'type'],
          'terminal_echo',
          MapBadges.terminalEcho,
          'parallel_soul',
          MapBadges.parallelSoul,
          'destination_thread',
          MapBadges.destinationThread,
          'baton_touch',
          MapBadges.batonTouch,
          MapBadges.terminalEcho,
        ],
        iconSize: _kPinSize,
        iconAllowOverlap: true,
      ),
    );

    _styleReady = true;
    if (!mounted) return;
    await _setSourceData(
      _kBoundarySource,
      ref.read(worldMapControllerProvider).airportBoundariesGeoJson,
    );
    await _syncPins();
  }

  // --- Location tracking & connectivity ------------------------------------

  void _startTracking() {
    _positionSub = ref
        .read(locationRepositoryProvider)
        .watchPosition()
        .listen(_onPosition);
  }

  void _onPosition(LocationCoordinates at) {
    ref.read(worldMapControllerProvider.notifier).updateUserLocation(at);
    final map = _map;
    if (_following && map != null) {
      unawaited(
        map.easeTo(
          CameraOptions(
            center: Point(coordinates: Position(at.longitude, at.latitude)),
          ),
          MapAnimationOptions(duration: 600),
        ),
      );
    }
    final last = _lastDetectedAt;
    if (last == null || last.distanceTo(at) >= _redetectDistanceMeters) {
      // Expo re-detects the airport channel as the traveler moves.
      _lastDetectedAt = at;
      unawaited(ref.read(airportControllerProvider.notifier).detectAirport());
    }
  }

  void _trackSlowLoading(bool loading) {
    if (!loading) {
      _slowTimer?.cancel();
      _slowTimer = null;
      if (_slow) setState(() => _slow = false);
      return;
    }
    _slowTimer ??= Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  /// Expo's map theming over dark-v11 (`MapDisplay.tsx`): terrain, dark
  /// water with a sheen, and 3D buildings from zoom 13. Expo's two "land"
  /// fills are not ported: they read a `land` source layer that Mapbox
  /// Streets v8 doesn't have, so they draw nothing in Expo either.
  ///
  /// On low-end phones ([_kLiteMap]) terrain and 3D buildings are skipped.
  Future<void> _addMapTheme(StyleManager style) async {
    if (!_kLiteMap) {
      const demId = 'map-theme-terrain-dem';
      await style.addSource(
        RasterDemSource(
          id: demId,
          url: 'mapbox://mapbox.terrain-rgb',
          tileSize: 512,
          maxzoom: 14,
        ),
      );
      await style.setStyleTerrain(
        jsonEncode({'source': demId, 'exaggeration': 1.08}),
      );
    }

    const streets = 'map-theme-contrast-source';
    await style.addSource(
      VectorSource(id: streets, url: 'mapbox://mapbox.mapbox-streets-v8'),
    );
    await style.addLayer(
      FillLayer(
        id: 'map-theme-water-base',
        sourceId: streets,
        sourceLayer: 'water',
        fillColor: const Color.fromRGBO(3, 5, 9, 0.94).toARGB32(),
        fillOpacity: 0.94,
        fillOutlineColor: const Color.fromRGBO(82, 104, 132, 0.26).toARGB32(),
      ),
    );
    await style.addLayer(
      FillLayer(
        id: 'map-theme-water-sheen',
        sourceId: streets,
        sourceLayer: 'water',
        fillColor: const Color.fromRGBO(36, 46, 62, 0.16).toARGB32(),
        fillOpacityExpression: [
          'interpolate', ['linear'], ['zoom'], //
          2.8, 0.22, 8, 0.14, 14, 0.07,
        ],
      ),
    );
    if (_kLiteMap) return;
    await style.addLayer(
      FillExtrusionLayer(
        id: 'map-theme-buildings-3d',
        sourceId: streets,
        sourceLayer: 'building',
        filter: [
          '==',
          ['get', 'extrude'],
          'true',
        ],
        minZoom: 13,
        fillExtrusionColor:
            const Color.fromRGBO(170, 156, 132, 0.85).toARGB32(),
        fillExtrusionHeightExpression: ['get', 'height'],
        fillExtrusionBaseExpression: [
          'coalesce',
          ['get', 'min_height'],
          0,
        ],
        fillExtrusionOpacityExpression: [
          'interpolate', ['linear'], ['zoom'], //
          13, 0.1, 15, 0.38, 17, 0.58,
        ],
      ),
    );
  }

  // --- Camera --------------------------------------------------------------

  void _centerOnUser(LocationCoordinates at, {bool animated = true}) {
    final map = _map;
    if (map == null) return;
    _centeredOnUser = true;
    final camera = CameraOptions(
      center: Point(coordinates: Position(at.longitude, at.latitude)),
      zoom: animated ? _kRecenterZoom : _kUserZoom,
    );
    unawaited(
      animated
          ? map.flyTo(camera, MapAnimationOptions(duration: 900))
          : map.setCamera(camera),
    );
  }

  /// The user panned: stop following them (Expo `onMapInteraction`).
  void _stopFollowing() {
    if (_following) setState(() => _following = false);
  }

  void _recenterToUser() {
    final location = ref.read(worldMapControllerProvider).userLocation;
    if (location == null) return;
    setState(() => _following = true);
    _centerOnUser(location);
  }

  void _flyToAirport(AirportEntity airport) {
    final map = _map;
    final lat = airport.latitude;
    final lng = airport.longitude;
    if (map == null || lat == null || lng == null) return;
    setState(() => _following = false);
    unawaited(
      map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: _kAirportZoom,
        ),
        MapAnimationOptions(duration: 900),
      ),
    );
  }

  Future<void> _openAirportSearch() async {
    final airport = await context.push<AirportEntity>(RouteNames.airportSearch);
    if (airport == null || !mounted) return;
    ref.read(worldMapControllerProvider.notifier).selectAirport(airport);
    _flyToAirport(airport);
  }

  void _onMapIdle(MapIdleEventData _) {
    if (_styleReady && !_renderSettled) {
      // Rendered. Clear the marker only after the map has stayed up a
      // little, since weak GPUs can crash just after the first frame.
      _renderSettled = true;
      _loadTimeout?.cancel();
      unawaited(Future<void>.delayed(_kMapStableFor, _guard.loaded));
    }
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_refreshForViewport()),
    );
  }

  Future<void> _refreshForViewport() async {
    final map = _map;
    if (map == null) return;
    final camera = await map.getCameraState();
    final bounds = await map.coordinateBoundsForCamera(
      CameraOptions(
        center: camera.center,
        zoom: camera.zoom,
        bearing: camera.bearing,
        pitch: camera.pitch,
      ),
    );
    if (!mounted) return;
    unawaited(
      map.gestures.updateSettings(
        GesturesSettings(rotateEnabled: camera.zoom > _kGestureLockZoom),
      ),
    );
    final west = bounds.southwest.coordinates.lng.toDouble();
    final south = bounds.southwest.coordinates.lat.toDouble();
    final east = bounds.northeast.coordinates.lng.toDouble();
    final north = bounds.northeast.coordinates.lat.toDouble();
    final controller = ref.read(worldMapControllerProvider.notifier)
      ..updateVisibleBoundaries(
        west: west,
        south: south,
        east: east,
        north: north,
        zoom: camera.zoom,
      );
    await controller.fetchEchoNodesForBounds(
      west: west,
      south: south,
      east: east,
      north: north,
    );
  }

  // --- Taps ----------------------------------------------------------------

  void _onPinTap(FeaturesetFeature feature) {
    final props = feature.properties;
    final id = (props['id'] ?? feature.id?.id)?.toString();
    if (id == null || id.isEmpty) return;
    final type = props['type']?.toString() ?? 'terminal_echo';
    unawaited(_openPin(id, type));
  }

  /// Opens the pin's card, enlarging its badge until the card closes.
  Future<void> _openPin(String id, String type) async {
    await _setSelectedPin(id);
    if (!mounted) return;
    await context.push(RouteNames.mapEchoFor(id, type));
    await _setSelectedPin(null);
  }

  Future<void> _setSelectedPin(String? id) async {
    final map = _map;
    if (map == null || !_styleReady) return;
    await map.style.setStyleLayerProperty(
      _kPinLayer,
      'icon-size',
      id == null
          ? _kPinSize
          : [
              'case',
              [
                '==',
                ['get', 'id'],
                id,
              ],
              _kSelectedPinSize,
              _kPinSize,
            ],
    );
  }

  /// Zooms into a cluster far enough to split it (Mapbox's expansion zoom).
  Future<void> _onClusterTap(FeaturesetFeature feature) async {
    final map = _map;
    final coords = feature.geometry['coordinates'];
    if (map == null || coords is! List || coords.length < 2) return;
    final center = Point(
      coordinates: Position(
        (coords[0]! as num).toDouble(),
        (coords[1]! as num).toDouble(),
      ),
    );
    final current = (await map.getCameraState()).zoom;
    var zoom = current + 2;
    try {
      final expansion = await map.getGeoJsonClusterExpansionZoom(_kPinsSource, {
        'type': 'Feature',
        'geometry': feature.geometry,
        'properties': feature.properties,
      });
      zoom = double.tryParse(expansion.value ?? '') ?? zoom;
    } on Object catch (_) {
      // Fall back to a fixed step in.
    }
    setState(() => _following = false);
    await map.easeTo(
      CameraOptions(center: center, zoom: zoom.clamp(current + 1, 18)),
      MapAnimationOptions(duration: 320),
    );
  }
}

// --- Heatmap expressions, verbatim from TerminalMapNodesLayer.tsx -----------

const List<Object> _freshness = [
  'coalesce',
  ['get', 'freshnessScore'],
  1,
];
const List<Object> _activity = [
  'coalesce',
  ['get', 'activityScore'],
  0,
];
const List<Object> _heatmapWeight = [
  'min',
  1.55,
  [
    '+',
    0.72,
    ['*', _activity, 0.16],
    ['*', _freshness, 0.05],
  ],
];
const List<Object> _heatmapIntensity = [
  'interpolate', ['linear'], ['zoom'], //
  2, 0.45, 5, 0.6, 8, 0.9, 11, 1.08, 13, 1.02, 16, 0.78,
];
const List<Object> _heatmapRadius = [
  'interpolate', ['linear'], ['zoom'], //
  2, 24, 5, 30, 8, 40, 11, 50, 13, 46, 16, 30,
];
const List<Object> _heatmapOpacity = [
  'interpolate', ['linear'], ['zoom'], //
  2, 0.34, 5, 0.44, 8, 0.58, 11, 0.68, 13, 0.58, 16, 0.34, 18, 0.14,
];
const List<Object> _heatmapColor = [
  'interpolate', ['linear'], ['heatmap-density'], //
  0, 'rgba(0,0,0,0)',
  0.12, 'rgba(50, 120, 255, 0.14)',
  0.28, 'rgba(38, 198, 255, 0.24)',
  0.48, 'rgba(0, 224, 153, 0.34)',
  0.66, 'rgba(187, 228, 10, 0.5)',
  0.82, 'rgba(255, 183, 84, 0.62)',
  0.93, 'rgba(255, 123, 54, 0.72)',
];

// --- Overlays --------------------------------------------------------------

/// Expo's `TerminalMapSearchBar`: opens airport search.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'SEARCH AIRPORT...',
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expo's `MapConnectivityBanner`: why pins may be stale. Informational
/// only — the map keeps showing cached data.
class _ConnectivityBanner extends StatelessWidget {
  const _ConnectivityBanner({required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: offline
              ? colors.error.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (offline)
            Icon(Icons.cloud_off_rounded, size: 15, color: colors.error)
          else
            const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            offline ? 'NO INTERNET — SHOWING SAVED DATA' : 'SLOW CONNECTION…',
            style: TextStyle(
              color: offline ? colors.error : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Expo's `MapActionFabStack` button (56 dp, dark, circular).
class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.78),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 56,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the map when this phone couldn't render it.
class _MapUnsupportedNotice extends StatelessWidget {
  const _MapUnsupportedNotice({
    required this.onRetry,
    required this.onOpenFeed,
  });

  final VoidCallback onRetry;
  final VoidCallback onOpenFeed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: AppSpacing.edgeInsetsLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 48, color: colors.textMuted),
                const SizedBox(height: AppSpacing.md),
                Text(
                  "Map isn't available on this phone",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "The map couldn't load on this device, so it's turned off. "
                  'Everything else still works.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: onOpenFeed,
                  child: const Text('Open Feed'),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Try the map again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
