import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/location/location_repository_impl.dart';
import 'package:gate_closes/core/services/connectivity_service.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_pin_plan.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_radar.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_features.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_offer.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_view_bounds.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/offer_map_repository.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/map_lighting_controller.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/map_render_guard.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/world_map_controller.dart';
import 'package:gate_closes/features/worldMap/presentation/map_badges.dart';
import 'package:gate_closes/features/worldMap/presentation/widgets/echo_stack_sheet.dart';
import 'package:gate_closes/features/worldMap/presentation/widgets/offer_banner.dart';
import 'package:gate_closes/features/worldMap/presentation/widgets/offer_sheet.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/map_bottom_nav.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const Map<String, Object> _kEmptyFeatureCollection = {
  'type': 'FeatureCollection',
  'features': <Object>[],
};

const _kBoundarySource = 'airport-boundaries-source';
const _kRadarGridSource = 'airport-radar-grid-source';
const _kRadarSweepSource = 'airport-radar-sweep-source';

/// Radar color: the app's lime accent.
const Color _kRadarColor = Color(0xFFBBE40A);

/// Below this zoom an airport circle is a few dozen pixels wide: no radar.
const double _kRadarMinZoom = 10;

/// Radar only on the airports nearest the view center: the grid is re-sent
/// on every camera move and the sweep on every frame, so both stay small.
const int _kMaxRadarDiscs = 12;
const int _kMaxSweepDiscs = 6;

/// One full sweep turn and the beam's frame interval.
const Duration _kSweepPeriod = Duration(seconds: 4);
const Duration _kSweepFrame = Duration(milliseconds: 66);

/// Zoomed out, the map shows no markers: a heat cloud per airport with
/// echoes, bigger and hotter with more of them (AirportEchoCount).
const _kCloudSource = 'airport-cloud-source';
const _kCloudLayer = 'airport-cloud';

/// A heatmap can't be tapped: an invisible circle the size of each cloud's
/// core takes the tap and flies into that airport, where its pins show.
const _kCloudTapLayer = 'airport-cloud-tap';
const double _kCloudTapRadius = 22;

/// Over the cloud, a radar "ping": a faint ring that pulses outward and
/// fades, wider for busier airports. Animation only; lite maps skip it
/// (a still ring would just look like a pin).
const _kPingSource = 'airport-ping-source';
const _kPingRingLayer = 'airport-ping-ring';
const Duration _kPingPeriod = Duration(milliseconds: 2400);
const Duration _kPingFrame = Duration(milliseconds: 66);
const double _kPingMinRadius = 3;
const double _kPingMaxRadius = 18;
const _kPinsSource = 'echo-symbols-source';
const _kClusterLayer = 'echo-clusters';
const _kPinLayer = 'echo-symbols';

/// Offers (ads, vouchers): unclustered, their own badge, above echo pins.
const _kOfferSource = 'offer-pins-source';
const _kOfferLayer = 'offer-pins';

/// Pins cluster up to this zoom. Coordinates are rounded to ~110 m, so pins
/// at different spots split by zoom 16; pins at the same spot never split,
/// and staying clustered keeps them from stacking invisibly on one point.
const double _kClusterMaxZoom = 19;

/// A cluster that only splits beyond this zoom opens a list instead.
const double _kStackZoom = 18;

/// Marker sizes by zoom (pins and cluster bubbles show from zoom 7; below
/// it the map shows only the heatmap cloud): small through the mid zooms,
/// growing only once zoomed in (from ~12), and capped at the last stop
/// (Mapbox holds it beyond). Pins reach Expo's 0.72 at zoom 16.
const List<(double, double)> _kPinSizes = [
  (6, 0.28),
  (11, 0.34),
  (14, 0.55),
  (16, 0.72),
];
const List<(double, double)> _kBubbleSizes = [
  (2, 0.28),
  (8, 0.32),
  (12, 0.4),
  (14, 0.5),
  (16, 0.55),
];
const List<(double, double)> _kBubbleTextSizes = [(2, 8), (12, 9), (15, 10)];

/// The pin whose card is open is this much bigger than the others.
const double _kSelectedPinScale = 1.18;

/// A ping ring's radius, wider for airports with more echoes.
List<Object> _pingRadius(double radius) => [
      '*',
      radius,
      [
        'coalesce',
        ['get', 'heatWeight'],
        1,
      ],
    ];

/// `['interpolate', ['linear'], ['zoom'], z, size(v), …]` over [stops].
List<Object> _byZoom(
  List<(double, double)> stops, [
  Object Function(double v)? size,
]) =>
    [
      'interpolate',
      ['linear'],
      ['zoom'],
      for (final (z, v) in stops) ...[z, size?.call(v) ?? v],
    ];

/// Pin size by zoom; the pin [selectedId] a little bigger.
List<Object> _pinSize(String? selectedId) => selectedId == null
    ? _byZoom(_kPinSizes)
    : _byZoom(
        _kPinSizes,
        (v) => [
          'case',
          [
            '==',
            ['get', 'id'],
            selectedId,
          ],
          v * _kSelectedPinScale,
          v,
        ],
      );

/// 32-bit ARM Android phones are low-end (small RAM, weak GPUs such as
/// PowerVR GE8320); terrain and 3D buildings stop the map opening there.
final bool _kLiteMap = Abi.current() == Abi.androidArm;

/// How long the map may take to render before this phone is treated as
/// unable to show it, and how long it must then stay up to count as working.
const Duration _kMapLoadTimeout = Duration(seconds: 25);
const Duration _kMapStableFor = Duration(seconds: 5);

/// At or below this zoom, rotation is locked (Expo's gesture lock).
const double _kGestureLockZoom = 3.5;

/// The compass sits this far below the safe area: under the search pill
/// (its top gap + ~48 height), not over the status bar or the pill.
const double _kCompassTop = AppSpacing.sm + 48 + AppSpacing.sm;

/// Expo map-shell zoom levels.
const double _kMinZoom = 2.8;
const double _kUserZoom = 14;
const double _kRecenterZoom = 16;
const double _kAirportZoom = 13;

/// The map tab — home of the app, as in the Expo map shell
/// (`app/(tabs)/map/index.tsx`): a full-screen Mapbox canvas with airport
/// boundaries, airport heat clouds and clustered echo pins, a search pill on
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

  /// The offer layer was added. False on a phone that can't add it: offers
  /// are then simply not shown and the map works as before.
  bool _offersReady = false;

  /// Offer cards hidden with × (for this session), and offers already
  /// counted as seen (one view per offer per session).
  final Set<String> _dismissedOffers = {};
  final Set<String> _seenOffers = {};
  bool _mapLoaded = false;
  Timer? _boundsDebounce;

  /// False when the radar layers couldn't be added or updated on this phone:
  /// the radar is then hidden, never drawn half-way. Circles and pins stay.
  bool _radarReady = false;

  /// Airport circles that get the radar grid, nearest the view center first.
  List<RadarDisc> _radarDiscs = const [];

  /// The camera as of the last viewport refresh, to pick [_radarDiscs].
  Point? _viewCenter;
  double _viewZoom = 0;
  Timer? _sweepTicker;
  final Stopwatch _sweepClock = Stopwatch();

  /// False when the ping layers couldn't be added or updated on this phone:
  /// the pings are then hidden; the heatmap cloud stays.
  bool _pingReady = false;
  Timer? _pingTicker;
  final Stopwatch _pingClock = Stopwatch();
  bool _pingInFlight = false;

  /// Pauses the sweep and the pings while the app is in the background.
  late final AppLifecycleListener _lifecycle;
  bool _appInForeground = true;

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
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _appInForeground = state == AppLifecycleState.resumed;
        _syncSweep();
        _syncPing();
      },
    );
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
      _mapLoaded = false;
    });
    _loadTimeout?.cancel();
    _loadTimeout = Timer(_kMapLoadTimeout, () {
      // Offline, the map can't load anyway; that's not the phone's fault.
      if (!mounted || _renderSettled) return;
      if (ref.read(isOfflineProvider).value ?? false) return;
      _renderSettled = true;
      _map = null;
      _styleReady = false;
      _mapLoaded = false;
      _radarReady = false;
      _sweepTicker?.cancel();
      _sweepTicker = null;
      _pingReady = false;
      _pingTicker?.cancel();
      _pingTicker = null;
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
    _sweepTicker?.cancel();
    _pingTicker?.cancel();
    _lifecycle.dispose();
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
              onMapLoadedListener: _onMapLoaded,
              // Not onMapIdle: the pulsing location puck redraws every
              // frame, so the map never goes idle once the user is located.
              onCameraChangeListener: (_) => _scheduleViewportRefresh(),
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
          if (_visibleOfferCard(state) case final card?)
            Positioned(
              left: AppSpacing.md,
              // Clear of the recenter button on the right.
              right: state.userLocation != null
                  ? AppSpacing.md + 56 + AppSpacing.sm
                  : AppSpacing.md,
              bottom: navClearance + AppSpacing.md,
              child: OfferBanner(
                offer: card,
                onOpen: () => unawaited(_openOffer(card)),
                onDismiss: () => setState(() => _dismissedOffers.add(card.id)),
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
      unawaited(_setBoundaries(next.airportBoundariesGeoJson));
    }
    if (previous?.echoNodes != next.echoNodes ||
        previous?.pinMode != next.pinMode ||
        previous?.airportCounts != next.airportCounts) {
      unawaited(_syncPins());
    }
    if (previous?.offerPins != next.offerPins ||
        previous?.pinMode != next.pinMode) {
      unawaited(_syncOffers());
    }
    final card = _visibleOfferCard(next);
    if (card != null && card != _visibleOfferCard(previous)) {
      _trackSeen(card);
    }
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

  /// Boundary circles plus their radar grid; restarts the sweep for them.
  Future<void> _setBoundaries(Map<String, dynamic>? boundaries) async {
    final center = _viewCenter?.coordinates;
    _radarDiscs = !_radarReady || center == null || _viewZoom < _kRadarMinZoom
        ? const []
        : AirportRadar.nearest(
            AirportRadar.discs(boundaries),
            lng: center.lng.toDouble(),
            lat: center.lat.toDouble(),
            count: _kMaxRadarDiscs,
          );
    await _setSourceData(_kBoundarySource, boundaries);
    if (_radarReady) {
      try {
        await _setSourceData(
          _kRadarGridSource,
          AirportRadar.grid(_radarDiscs),
        );
      } on Object catch (e) {
        _disableRadar(e);
        return;
      }
    }
    _syncSweep();
  }

  /// Hides the radar for the rest of this map session after a failure, so
  /// a phone that can't draw it shows plain circles instead of a broken one.
  void _disableRadar(Object error) {
    debugPrint('Map radar off: $error');
    _radarReady = false;
    _radarDiscs = const [];
    _syncSweep();
    unawaited(
      _setSourceData(_kRadarGridSource, null).catchError((Object _) {}),
    );
  }

  /// Runs the sweep only while circles are on screen and the app is in the
  /// foreground, and never on lite maps, where per-frame updates are too heavy.
  void _syncSweep() {
    final run = !_kLiteMap &&
        _radarReady &&
        _appInForeground &&
        _styleReady &&
        _radarDiscs.isNotEmpty;
    if (!run) {
      _sweepTicker?.cancel();
      _sweepTicker = null;
      _sweepClock.stop();
      unawaited(
        _setSourceData(_kRadarSweepSource, null).catchError((Object _) {}),
      );
      return;
    }
    _sweepClock.start();
    _sweepTicker ??= Timer.periodic(_kSweepFrame, (_) => _drawSweep());
  }

  bool _sweepInFlight = false;

  Future<void> _drawSweep() async {
    // Skip a frame rather than queue bridge calls behind a slow one.
    if (_sweepInFlight) return;
    _sweepInFlight = true;
    final period = _kSweepPeriod.inMilliseconds;
    final heading = (_sweepClock.elapsedMilliseconds % period) / period * 360;
    final discs = _radarDiscs.take(_kMaxSweepDiscs).toList();
    try {
      await _setSourceData(
        _kRadarSweepSource,
        AirportRadar.sweep(discs, heading),
      );
    } on Object catch (e) {
      _disableRadar(e);
    } finally {
      _sweepInFlight = false;
    }
  }

  /// Zoomed in: the airports' pins, no heat.
  /// Zoomed out: no markers, only the airport clouds (and pings).
  Future<void> _syncPins() async {
    final state = ref.read(worldMapControllerProvider);
    final counts = state.pinMode == MapPinMode.counts;
    final pins = counts ? null : EchoMapFeatures.collection(state.echoNodes);
    final airports =
        counts ? AirportEchoCount.collection(state.airportCounts) : null;
    await _setSourceData(_kPinsSource, pins);
    await _setSourceData(_kCloudSource, airports);
    if (_pingReady) {
      try {
        await _setSourceData(_kPingSource, airports);
      } on Object catch (e) {
        _disablePing(e);
      }
    }
    _syncPing();
    await _syncOffers();
  }

  /// Offer pins of the airports in view; none when zoomed out.
  Future<void> _syncOffers() async {
    if (!_offersReady) return;
    final state = ref.read(worldMapControllerProvider);
    final offers = state.pinMode == MapPinMode.pins
        ? OfferMapFeatures.collection(state.offerPins)
        : null;
    try {
      await _setSourceData(_kOfferSource, offers);
    } on Object catch (e) {
      // Offers are extra: drop them rather than disturb the map.
      debugPrint('Map offers disabled: $e');
      _offersReady = false;
    }
  }

  /// The offer card to show over the map, unless hidden with ×.
  MapOffer? _visibleOfferCard(WorldMapState? state) {
    final card = state?.offerCard;
    if (card == null || state?.pinMode != MapPinMode.pins) return null;
    return _dismissedOffers.contains(card.id) ? null : card;
  }

  void _trackSeen(MapOffer offer) {
    if (!_seenOffers.add(offer.id)) return;
    ref
        .read(worldMapControllerProvider.notifier)
        .trackOffer(offer, OfferEvent.view);
  }

  /// Animates the ping rings only while airports are pinged, the app is in
  /// the foreground, and never on lite maps (static ring there).
  void _syncPing() {
    final state = ref.read(worldMapControllerProvider);
    final run = !_kLiteMap &&
        _pingReady &&
        _appInForeground &&
        _styleReady &&
        state.pinMode == MapPinMode.counts &&
        state.airportCounts.isNotEmpty;
    if (!run) {
      _pingTicker?.cancel();
      _pingTicker = null;
      _pingClock.stop();
      return;
    }
    _pingClock.start();
    _pingTicker ??= Timer.periodic(_kPingFrame, (_) => _drawPing());
  }

  Future<void> _drawPing() async {
    final map = _map;
    // Skip a frame rather than queue bridge calls behind a slow one.
    if (map == null || _pingInFlight) return;
    _pingInFlight = true;
    final period = _kPingPeriod.inMilliseconds;
    final t = (_pingClock.elapsedMilliseconds % period) / period;
    final radius = _kPingMinRadius + (_kPingMaxRadius - _kPingMinRadius) * t;
    try {
      await map.style.setStyleLayerProperty(
        _kPingRingLayer,
        'circle-radius',
        _pingRadius(radius),
      );
      await map.style.setStyleLayerProperty(
        _kPingRingLayer,
        'circle-stroke-opacity',
        0.85 * (1 - t),
      );
    } on Object catch (e) {
      _disablePing(e);
    } finally {
      _pingInFlight = false;
    }
  }

  /// Hides the pings for the rest of this map session after a failure, so
  /// a phone that can't draw them shows just the cloud.
  void _disablePing(Object error) {
    debugPrint('Map pings off: $error');
    _pingReady = false;
    _syncPing();
    unawaited(_setSourceData(_kPingSource, null).catchError((Object _) {}));
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
    // Mapbox draws its ornaments under the status bar. Expo hid the scale
    // bar (it also showed miles); the compass moves below the search pill.
    unawaited(map.scaleBar.updateSettings(ScaleBarSettings(enabled: false)));
    unawaited(
      map.compass.updateSettings(
        CompassSettings(
          position: OrnamentPosition.TOP_RIGHT,
          marginTop: MediaQuery.viewPaddingOf(context).top + _kCompassTop,
          marginRight: AppSpacing.md,
        ),
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
      )
      ..addInteraction(
        TapInteraction(
          FeaturesetDescriptor(layerId: _kCloudTapLayer),
          (feature, _) => unawaited(_onCloudTap(feature)),
        ),
        interactionID: 'tap-airport-clouds',
      )
      ..addInteraction(
        TapInteraction(
          FeaturesetDescriptor(layerId: _kOfferLayer),
          (feature, _) => _onOfferTap(feature),
        ),
        interactionID: 'tap-offer-pins',
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

    // Airport boundaries as radar scopes: tinted disc, sweep beam, grid
    // (rings, spokes, edge ticks), then a glowing outline on top.
    const radar = _kRadarColor;
    await style.addSource(GeoJsonSource(id: _kBoundarySource, data: empty));
    await style.addLayer(
      FillLayer(
        id: 'airport-boundaries-fill',
        sourceId: _kBoundarySource,
        fillColor: radar.toARGB32(),
        fillOpacity: 0.05,
      ),
    );
    // The radar is decoration too: if this phone can't add it, the circles
    // and pins load without it (see [_disableRadar]).
    try {
      await style.addSource(
        GeoJsonSource(id: _kRadarSweepSource, data: empty),
      );
      await style.addSource(GeoJsonSource(id: _kRadarGridSource, data: empty));
      await style.addLayer(
        FillLayer(
          id: 'airport-radar-sweep',
          sourceId: _kRadarSweepSource,
          fillColor: radar.toARGB32(),
          fillOpacityExpression: [
            '*',
            0.32,
            ['get', 'alpha'],
          ],
          fillAntialias: false,
        ),
      );
      await style.addLayer(
        LineLayer(
          id: 'airport-radar-grid',
          sourceId: _kRadarGridSource,
          lineColor: radar.toARGB32(),
          lineOpacityExpression: [
            'match', ['get', 'kind'], //
            'tickMajor', 0.75,
            'tick', 0.45,
            'ring', 0.28,
            0.18, // spoke
          ],
          lineWidthExpression: [
            'match', ['get', 'kind'], //
            'tickMajor', 1.6,
            'tick', 1.0,
            0.8, // ring, spoke
          ],
        ),
      );
      _radarReady = true;
    } on Object catch (e) {
      _radarReady = false;
      debugPrint('Map radar skipped: $e');
    }
    await style.addLayer(
      LineLayer(
        id: 'airport-boundaries-outline-glow',
        sourceId: _kBoundarySource,
        lineColor: radar.toARGB32(),
        lineOpacity: 0.3,
        lineWidth: 7,
        lineBlur: 4,
      ),
    );
    await style.addLayer(
      LineLayer(
        id: 'airport-boundaries-outline',
        sourceId: _kBoundarySource,
        lineColor: radar.toARGB32(),
        lineOpacity: 0.9,
        lineWidth: 1.5,
      ),
    );

    // Zoomed out only: one heat cloud per airport, tuned to show from a
    // single point.
    await style.addSource(GeoJsonSource(id: _kCloudSource, data: empty));
    await style.addLayer(
      HeatmapLayer(
        id: _kCloudLayer,
        sourceId: _kCloudSource,
        heatmapWeightExpression: [
          'coalesce',
          ['get', 'heatWeight'],
          1,
        ],
        heatmapIntensityExpression: _cloudIntensity,
        heatmapRadiusExpression: _cloudRadius,
        heatmapOpacity: 0.9,
        heatmapColorExpression: _cloudColor,
      ),
    );
    await style.addLayer(
      CircleLayer(
        id: _kCloudTapLayer,
        sourceId: _kCloudSource,
        circleRadiusExpression: ['*', _kCloudTapRadius, _cloudScale],
        circleColor: Colors.transparent.toARGB32(),
        circleOpacity: 0,
      ),
    );

    // Radar pings over the clouds. Decoration, and animation only: lite
    // maps skip them, and if this phone can't add them the clouds and pins
    // load without them (see [_disablePing]).
    if (!_kLiteMap) {
      try {
        await style.addSource(GeoJsonSource(id: _kPingSource, data: empty));
        await style.addLayer(
          CircleLayer(
            id: _kPingRingLayer,
            sourceId: _kPingSource,
            circleRadiusExpression: _pingRadius(_kPingMinRadius),
            circleColor: Colors.transparent.toARGB32(),
            circleStrokeColor: _kRadarColor.toARGB32(),
            circleStrokeWidth: 1.4,
            circleStrokeOpacity: 0,
          ),
        );
        _pingReady = true;
      } on Object catch (e) {
        _pingReady = false;
        debugPrint('Map pings skipped: $e');
      }
    }

    // Clustered pins with per-type badges.
    await style.addSource(
      GeoJsonSource(
        id: _kPinsSource,
        data: empty,
        cluster: true,
        clusterRadius: 45,
        clusterMaxZoom: _kClusterMaxZoom,
      ),
    );
    await style.addLayer(
      SymbolLayer(
        id: _kClusterLayer,
        sourceId: _kPinsSource,
        filter: ['has', 'point_count'],
        iconImage: MapBadges.cluster,
        iconSizeExpression: _byZoom(_kBubbleSizes),
        iconAllowOverlap: true,
        textFieldExpression: ['get', 'point_count_abbreviated'],
        textSizeExpression: _byZoom(_kBubbleTextSizes),
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
        iconSizeExpression: _pinSize(null),
        iconAllowOverlap: true,
      ),
    );

    // Offers are extra: if this phone can't add their layer, the echo pins
    // and everything else still load (offers just aren't shown).
    try {
      await style.addSource(GeoJsonSource(id: _kOfferSource, data: empty));
      await style.addLayer(
        SymbolLayer(
          id: _kOfferLayer,
          sourceId: _kOfferSource,
          iconImage: MapBadges.offer,
          iconSizeExpression: _byZoom(_kPinSizes),
          iconAllowOverlap: true,
        ),
      );
      _offersReady = true;
    } on Object catch (e) {
      debugPrint('Map offers skipped: $e');
    }

    _styleReady = true;
    if (!mounted) return;
    await _setBoundaries(
      ref.read(worldMapControllerProvider).airportBoundariesGeoJson,
    );
    await _syncPins();
    _settleRenderIfReady();
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

  void _onMapLoaded(MapLoadedEventData _) {
    _mapLoaded = true;
    _settleRenderIfReady();
  }

  /// Once the map has loaded and our layers are added, the map works here.
  void _settleRenderIfReady() {
    if (!_mapLoaded || !_styleReady || _renderSettled) return;
    // Clear the marker only after the map has stayed up a little, since
    // weak GPUs can crash just after the first frame.
    _renderSettled = true;
    _loadTimeout?.cancel();
    unawaited(Future<void>.delayed(_kMapStableFor, _guard.loaded));
    _scheduleViewportRefresh();
  }

  /// Loads boundaries and pins for the view once the camera settles.
  void _scheduleViewportRefresh() {
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
    final view = MapViewBounds.normalize(
      west: bounds.southwest.coordinates.lng.toDouble(),
      south: bounds.southwest.coordinates.lat.toDouble(),
      east: bounds.northeast.coordinates.lng.toDouble(),
      north: bounds.northeast.coordinates.lat.toDouble(),
      centerLng: camera.center.coordinates.lng.toDouble(),
    );
    _viewCenter = camera.center;
    _viewZoom = camera.zoom;
    if (kDebugMode) {
      debugPrint(
        'Map view: zoom ${camera.zoom.toStringAsFixed(1)} at '
        '${camera.center.coordinates.lat.toStringAsFixed(3)}, '
        '${camera.center.coordinates.lng.toStringAsFixed(3)}',
      );
    }
    final west = view.west;
    final south = view.south;
    final east = view.east;
    final north = view.north;
    final controller = ref.read(worldMapControllerProvider.notifier)
      ..updateVisibleBoundaries(
        west: west,
        south: south,
        east: east,
        north: north,
        zoom: camera.zoom,
      );
    await controller.refreshForView(
      west: west,
      south: south,
      east: east,
      north: north,
      zoom: camera.zoom,
      centerLng: camera.center.coordinates.lng.toDouble(),
      centerLat: camera.center.coordinates.lat.toDouble(),
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

  void _onOfferTap(FeaturesetFeature feature) {
    final id = (feature.properties['id'] ?? feature.id?.id)?.toString();
    final offers = ref.read(worldMapControllerProvider).offerPins;
    final offer = offers.where((o) => o.id == id).firstOrNull;
    if (offer != null) unawaited(_openOffer(offer));
  }

  /// The offer's sheet; opening it counts as seeing it, its button as a
  /// click.
  Future<void> _openOffer(MapOffer offer) async {
    final controller = ref.read(worldMapControllerProvider.notifier);
    _trackSeen(offer);
    await OfferSheet.show(
      context,
      offer: offer,
      onOpenLink: () async {
        controller.trackOffer(offer, OfferEvent.click);
        final url = Uri.tryParse(offer.ctaUrl ?? '');
        if (url == null) return;
        final opened = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text("Couldn't open the link")),
          );
        }
      },
      onClaim: () => controller.claimOffer(offer),
    );
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
      _pinSize(id),
    );
  }

  /// Zooms into a cluster far enough to split it (Mapbox's expansion zoom).
  /// Echoes on one spot never split: those open a list instead.
  Future<void> _onClusterTap(FeaturesetFeature feature) async {
    final map = _map;
    final coords = feature.geometry['coordinates'];
    if (map == null || coords is! List || coords.length < 2) return;
    final cluster = <String?, Object?>{
      'type': 'Feature',
      'geometry': feature.geometry,
      'properties': feature.properties,
    };
    final echoes = await _clusterEchoes(map, cluster);
    if (echoes != null && _onOneSpot(echoes)) {
      await _openStack(echoes);
      return;
    }
    final center = Point(
      coordinates: Position(
        (coords[0]! as num).toDouble(),
        (coords[1]! as num).toDouble(),
      ),
    );
    final current = (await map.getCameraState()).zoom;
    var zoom = current + 2;
    try {
      final expansion =
          await map.getGeoJsonClusterExpansionZoom(_kPinsSource, cluster);
      zoom = double.tryParse(expansion.value ?? '') ?? zoom;
    } on Object catch (_) {
      // Fall back to a fixed step in.
    }
    if (zoom > _kStackZoom && echoes != null) {
      await _openStack(echoes);
      return;
    }
    setState(() => _following = false);
    await map.easeTo(
      CameraOptions(center: center, zoom: zoom.clamp(current + 1, 18)),
      MapAnimationOptions(duration: 320),
    );
  }

  /// The echoes inside a cluster (at most 100), or null if Mapbox can't
  /// list them on this phone.
  Future<List<TerminalEchoMapNodeEntity>?> _clusterEchoes(
    MapboxMap map,
    Map<String?, Object?> cluster,
  ) async {
    try {
      final leaves =
          await map.getGeoJsonClusterLeaves(_kPinsSource, cluster, 100, 0);
      final features = leaves.featureCollection;
      if (features == null || features.isEmpty) return null;
      return [
        for (final f in features.nonNulls)
          TerminalEchoMapNodeEntity.fromGeoJsonFeature(
            {for (final e in f.entries) e.key.toString(): e.value},
          ),
      ];
    } on Object catch (_) {
      return null;
    }
  }

  static bool _onOneSpot(List<TerminalEchoMapNodeEntity> echoes) =>
      echoes.every(
        (e) =>
            e.latitude == echoes.first.latitude &&
            e.longitude == echoes.first.longitude,
      );

  /// Flies from an airport's cloud into the airport, where its pins load.
  Future<void> _onCloudTap(FeaturesetFeature feature) async {
    final map = _map;
    final coords = feature.geometry['coordinates'];
    if (map == null || coords is! List || coords.length < 2) return;
    setState(() => _following = false);
    await map.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(
            (coords[0]! as num).toDouble(),
            (coords[1]! as num).toDouble(),
          ),
        ),
        zoom: _kAirportZoom,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  Future<void> _openStack(List<TerminalEchoMapNodeEntity> echoes) async {
    final picked = await EchoStackSheet.show(context, echoes);
    if (picked == null || !mounted) return;
    await _openPin(picked.id, EchoMapFeatures.typeKey(picked.nodeKind));
  }
}

// --- Airport cloud (zoomed out) ------------------------------------------

/// Cloud size grows with the airport's echoes (`cloudScale`).
const List<Object> _cloudScale = [
  'coalesce',
  ['get', 'cloudScale'],
  1,
];
const List<Object> _cloudRadius = [
  'interpolate', ['linear'], ['zoom'], //
  1, ['*', 22, _cloudScale],
  3, ['*', 30, _cloudScale],
  6, ['*', 46, _cloudScale],
];
const List<Object> _cloudIntensity = [
  'interpolate', ['linear'], ['zoom'], //
  1, 1.3, 6, 1.6,
];

/// Expo's pin heatmap colors, more opaque: a single point must show.
const List<Object> _cloudColor = [
  'interpolate', ['linear'], ['heatmap-density'], //
  0, 'rgba(0,0,0,0)',
  0.08, 'rgba(50, 120, 255, 0.25)',
  0.25, 'rgba(38, 198, 255, 0.45)',
  0.45, 'rgba(0, 224, 153, 0.6)',
  0.65, 'rgba(187, 228, 10, 0.72)',
  0.82, 'rgba(255, 183, 84, 0.82)',
  0.95, 'rgba(255, 123, 54, 0.9)',
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
