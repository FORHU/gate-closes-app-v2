import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/location/location_repository_impl.dart';
import 'package:gate_closes/core/services/connectivity_service.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_clouds.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_pin_plan.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_point.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_radar.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_visibility.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_beacons.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_features.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_offer.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_tier.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_view_bounds.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/offer_map_repository.dart';
import 'package:gate_closes/features/worldMap/presentation/airport_tags.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/map_lighting_controller.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/map_render_guard.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/map_tier_controller.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/world_map_controller.dart';
import 'package:gate_closes/features/worldMap/presentation/map_badges.dart';
import 'package:gate_closes/features/worldMap/presentation/widgets/airports_in_view_panel.dart';
import 'package:gate_closes/features/worldMap/presentation/widgets/echo_stack_sheet.dart';
import 'package:gate_closes/features/worldMap/presentation/widgets/offer_banner.dart';
import 'package:gate_closes/features/worldMap/presentation/widgets/offer_sheet.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/map_bottom_nav.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
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

/// Radar color (circles, sweep, grid): a radar-screen green, the green of
/// the map's heat ramp.
const Color _kRadarColor = Color(0xFF2ED573);

/// The app's lime accent, for the lit airport buildings and the map chips.
const Color _kLime = Color(0xFFBBE40A);

/// Overlays on the map use the dark palette whatever the app theme: the map
/// itself is always dark.
const GateColors _kUi = GateColors.dark;

/// Chumme's basemap palette. dark-v11 paints land and water two greys
/// 1.13:1 apart, one flat disc at globe distance; a deep green land and a
/// deep blue ocean are told apart by hue. Each entry repaints one of the
/// style's own layers: (layer, paint property, color).
const List<(String, String, String)> _kBasemapPalette = [
  ('land', 'background-color', 'hsl(140, 28%, 29%)'),
  ('national-park', 'fill-color', 'hsl(140, 30%, 33%)'),
  ('landuse', 'fill-color', 'hsl(140, 30%, 33%)'),
  ('water', 'fill-color', 'hsl(205, 55%, 20%)'),
  ('waterway', 'line-color', 'hsl(205, 55%, 20%)'),
];

/// Chumme's atmosphere: an unlit slate rim, near-black space, faint stars.
const Map<String, Object> _kAtmosphere = {
  'color': '#2e323e',
  'high-color': '#161922',
  'space-color': '#08080e',
  'star-intensity': 0.1,
};

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

/// The same airports as clouds (AirportClouds): a scatter of puffs each,
/// for the heat and the 3D glow's halo, so they read as clouds instead of
/// circles. Rebuilt when the zoom changes; taps, tags and the glow's core
/// stay on the airport points.
const _kPuffSource = 'airport-puff-source';
const _kCloudLayer = 'airport-cloud';

/// A heatmap can't be tapped: an invisible circle the size of each cloud's
/// core takes the tap and flies into that airport, where its pins show.
const _kCloudTapLayer = 'airport-cloud-tap';

/// The airports' tags (AirportTags) over the zoomed-out map.
const _kTagLayer = 'airport-tags';

/// Every other airport (no echoes), zoomed out: a dot and a glass tag with
/// its name and code (one shared plate, AirportTags.plateImage), under the
/// busy airports' tags. Where tags would overlap Mapbox shows the ones
/// that fit and the rest appear as the camera comes closer; the dots
/// always show.
const _kQuietSource = 'airport-quiet-source';
const _kQuietDotLayer = 'airport-quiet-dots';
const _kQuietNameLayer = 'airport-quiet-names';

/// Fonts both map styles carry (Standard and dark-v11).
const List<String> _kMapFont = ['DIN Pro Medium', 'Arial Unicode MS Regular'];
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

/// Only active airports pulse, as Chumme's sonar does, so a quiet map
/// doesn't flicker: busy ones (this many echoes) or fresh ones (an echo in
/// the last [AirportEchoCount.newMaxAge]).
const int _kPingMinEchoes = 3;
const List<Object> _kPingFilter = [
  'any',
  [
    '>=',
    ['get', 'count'],
    _kPingMinEchoes,
  ],
  [
    '==',
    ['get', 'freshnessScore'],
    2,
  ],
];

/// The 3D map's airport glow: a soft disc of light lying on the ground at
/// each airport, bigger with more echoes, breathing on the ping clock. It
/// replaces the flat heat and pings there; no tower (light beams were tried
/// and read as towers). Lime when fresh, otherwise Chumme's heat ramp by
/// activity: 0 for no echoes, 1 at 50 or more (log scale).
const _kGlowLayer = 'airport-glow';
const _kGlowCoreLayer = 'airport-glow-core';
const List<Object> _kGlowColor = [
  'case',
  [
    '==',
    ['get', 'freshnessScore'],
    2,
  ],
  '#BBE40A',
  [
    'interpolate', ['linear'], //
    [
      'min',
      1,
      [
        '/',
        [
          'ln',
          [
            '+',
            1,
            ['get', 'count'],
          ],
        ],
        3.9318256327243257,
      ],
    ],
    0, '#00DCFF',
    0.35, '#2ED573',
    0.55, '#FFD32A',
    0.75, '#FF6B35',
    1, '#FF1744',
  ],
];

/// Glow and core radius in points, times the airport's `cloudScale`
/// (1 to 2.4 with its echoes), growing a little as the camera comes in.
const List<(double, double)> _kGlowRadius = [(2, 10), (6, 14), (10, 18)];
const List<(double, double)> _kGlowCoreRadius = [(2, 3.5), (6, 5), (10, 6)];

/// On the 3D map, the real buildings inside the airport circles light up
/// lime: one extra extrusion layer over Standard's, filtered by Mapbox to
/// the airports' circles (`distance`), so no per-building calls. The filter
/// only changes when the nearby airports do, never per frame or per pan.
const _kAirportBuildingsSource = 'airport-buildings-source';
const _kAirportBuildingsLayer = 'airport-buildings';
const double _kAirportBuildingsMinZoom = 13;

/// Matches nothing: the buildings filter before any airport is near.
const List<Object> _kNoBuildings = ['boolean', false];

/// The in-view panel looks at the busiest this many airports facing the
/// camera.
const int _kLabelCandidates = 60;

/// Zoomed out the 3D map is seen tilted too, a gentle angle.
const double _kGlobePitch = 35;

/// Fresh activity pulses lime ("live"), busy airports in the heat's coral.
const List<Object> _kPingColor = [
  'match', ['get', 'freshnessScore'], //
  2, '#BBE40A',
  '#FF6B35',
];

/// Echoes (EchoBeacons), only from close up: a glow and a floor disc per
/// echo and an invisible finger-sized tap target. Colored by echo type, as
/// the pin cards.
const _kPinsSource = 'echo-symbols-source';
const _kPinGlowLayer = 'echo-glow';
const _kPinLayer = 'echo-discs';
const _kPinTapLayer = 'echo-tap';
const List<Object> _kEchoColor = [
  'match', ['get', 'type'], //
  'parallel_soul', '#50D6FF',
  'destination_thread', '#FFB457',
  'baton_touch', '#CF3573',
  '#BBE40A', // terminal_echo
];

/// Echoes fade in from just below the show zoom; fading ones (about to
/// expire) stay dimmer.
List<Object> _echoOpacity(
  double opacity, {
  double from = EchoBeacons.fadeInFrom,
  double to = EchoBeacons.fadeInTo,
}) =>
    [
      'interpolate', ['linear'], ['zoom'], //
      from, 0,
      to,
      [
        '*',
        opacity,
        [
          'match',
          ['get', 'freshnessScore'],
          0,
          0.55,
          1,
        ],
      ],
    ];

/// An echo's glow shows earlier than its disc: from the airport zoom, where
/// the radar appears, so the sweep lights up echoes inside it ("the glow
/// shows in the radar"). Small there, it grows into the disc's halo.
const double _kEchoGlowFrom = AirportPinPlan.pinsMinZoom;
const double _kEchoGlowTo = _kEchoGlowFrom + 0.5;
const List<(double, double)> _kEchoGlowRadius = [
  (_kEchoGlowFrom, 12),
  (14, 21),
  (16, 40),
  (18, 52),
  (20, 90),
  (22, 360),
];

/// Offers (ads, vouchers): unclustered, their own badge, above echo pins.
const _kOfferSource = 'offer-pins-source';
const _kOfferLayer = 'offer-pins';

/// Offer badge sizes by zoom; they show with the echoes, from close up.
const List<(double, double)> _kPinSizes = [
  (14, 0.55),
  (16, 0.72),
];

/// The radar sweep lights up the echoes it passes ("blips"), soft and
/// feathered like light clouds: as the arm crosses an echo its glow fades
/// in to [_kBlipPeak] over [_kBlipRiseDeg] of the turn, then eases back
/// out over [_kBlipFadeDeg] to a barely-there [_kBlipRest] until the next
/// pass. Echoes outside a radar disc keep a steady, faint glow.
const double _kBlipRiseDeg = 18;
const double _kBlipFadeDeg = 180;
const double _kBlipPeak = 0.55;
const double _kBlipRest = 0.06;
const double _kGlowOpacity = 0.3;

/// The glow's opacity with the arm at [headingDeg].
List<Object> _blipOpacity(double headingDeg) {
  // Degrees the arm has turned since it crossed this echo.
  final since = [
    '%',
    [
      '+',
      [
        '-',
        headingDeg,
        ['get', 'radarBearing'],
      ],
      720,
    ],
    360,
  ];
  return [
    'interpolate', ['linear'], ['zoom'], //
    _kEchoGlowFrom, 0,
    _kEchoGlowTo,
    [
      'case',
      ['has', 'radarBearing'],
      [
        'interpolate', ['linear'], since, //
        0, _kBlipRest,
        _kBlipRiseDeg, _kBlipPeak,
        // Eases out: quick at first, then lingering, as light fades.
        _kBlipRiseDeg + _kBlipFadeDeg * 0.25, _kBlipPeak * 0.6,
        _kBlipRiseDeg + _kBlipFadeDeg * 0.55, _kBlipPeak * 0.3,
        _kBlipRiseDeg + _kBlipFadeDeg, _kBlipRest,
        360, _kBlipRest,
      ],
      _kGlowOpacity,
    ],
  ];
}

/// The glow's steady opacity (no sweep running), from the airport zoom.
final List<Object> _echoGlowOpacity = _echoOpacity(
  _kGlowOpacity,
  from: _kEchoGlowFrom,
  to: _kEchoGlowTo,
);

/// The echo whose card is open: its disc is this much bigger.
const double _kSelectedPinScale = 1.6;

/// The disc's radius by zoom (exponential, as distances on the ground
/// scale), times [scale]; the echo [selectedId] bigger.
List<Object> _discRadius(String? selectedId, {double scale = 1}) => [
      'interpolate',
      ['exponential', 2],
      ['zoom'],
      for (final (z, r) in EchoBeacons.discRadius) ...[
        z,
        if (selectedId == null)
          r * scale
        else
          [
            'case',
            [
              '==',
              ['get', 'id'],
              selectedId,
            ],
            r * scale * _kSelectedPinScale,
            r * scale,
          ],
      ],
    ];

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

/// The glow's [opacity], faded out with the heat as the radar takes over.
List<Object> _glowOpacity(double opacity) => [
      'interpolate', ['linear'], ['zoom'], //
      _kHeatFadeStart, opacity,
      _kHeatFadeEnd, 0,
    ];

/// [stops] (zoom, points) times the airport's `cloudScale`.
List<Object> _glowRadius(List<(double, double)> stops) => _byZoom(
      stops,
      (r) => ['*', r, _cloudScale],
    );

/// The ring's [opacity] this frame, faded by zoom: too small to see below
/// zoom 3 (Chumme starts at 4), and gone with the heat into pins mode.
List<Object> _pingOpacity(double opacity) => [
      'interpolate', ['linear'], ['zoom'], //
      2, 0,
      3, opacity,
      _kHeatFadeStart, opacity,
      _kHeatFadeEnd, 0,
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

/// The map this phone gets, from the device ladder (MapTierController),
/// set before the map is created (see `_armMap`). Capable phones get Mapbox
/// Standard: a lit 3D city with landmarks and shadows, its light following
/// Map Lighting. Weak ones (32-bit, little RAM, old Android, or measured
/// too slow) get the lite map: dark-v11 with Chumme's palette, no terrain
/// or 3D buildings, which stop the map opening on GPUs such as PowerVR.
MapTier _mapTier = MapTier.lite;
bool get _kLiteMap => _mapTier == MapTier.lite;
bool get _kStandardMap => _mapTier == MapTier.standard;

/// Standard draws 3D buildings over everything without a slot; the airport
/// radar goes in its `middle` slot, on the ground under the buildings.
/// dark-v11 has no slots.
String? get _kGroundSlot => _kStandardMap ? 'middle' : null;

/// The 3D city is seen tilted: flying in close tilts the camera this far,
/// and the user may tilt it at any zoom.
const double _kCityPitch = 55;

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

/// The airport chip flies here: past the fade-in, where echoes are clear.
const double _kEchoesZoom = EchoBeacons.showZoom + 0.6;

/// The map tab — home of the app, as in the Expo map shell
/// (`app/(tabs)/map/index.tsx`): a full-screen Mapbox canvas with airport
/// boundaries, airport heat clouds or glow, and human-sized echoes from
/// close up (EchoBeacons), a search pill on top and a recenter button above
/// the navigation bar.
///
/// Tapping an echo opens its card (`/map/echo/:id`); a tap that covers
/// several opens the list of them. Architecture notes: `docs/MAP_EXPO_PARITY.md`.
class WorldMapPage extends ConsumerStatefulWidget {
  const WorldMapPage({super.key});

  @override
  ConsumerState<WorldMapPage> createState() => _WorldMapPageState();
}

class _WorldMapPageState extends ConsumerState<WorldMapPage> {
  MapboxMap? _map;
  bool _styleReady = false;

  /// The atmosphere was tried on this map's style (see [_setAtmosphere]):
  /// it reloads the style once, and must not again.
  bool _atmosphereTried = false;

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

  /// The zoom the cloud puffs were last scattered for (they keep their
  /// shape on screen); null when there are none.
  double? _puffZoom;

  /// The airport tag layer was added (zoomed out).
  bool _tagsReady = false;

  /// The quiet airports' dots and names were added.
  bool _quietReady = false;

  /// The airport glow was added (3D map). It breathes on the ping clock.
  bool _glowReady = false;

  /// False once the glow's breathing failed on this phone: it stays, still.
  bool _glowPulseOk = true;

  /// Airport labels and the airports in view, re-projected as the camera
  /// moves: one batched projection per update, skipping ahead to the
  /// newest camera rather than queueing calls.
  ///
  /// Held in a notifier so an update redraws only the labels and the panel,
  /// not the whole map page.
  final ValueNotifier<_LabelView> _labelView =
      ValueNotifier(const _LabelView());
  CameraState? _labelCamera;
  bool _labelsInFlight = false;

  /// The airport buildings layer was added (3D map).
  bool _buildingsReady = false;

  /// The airports its filter covers, to skip unchanged updates.
  String? _buildingsKey;

  /// The echoes as drawn (spread on shared spots), for taps.
  List<EchoBeacon> _beacons = const [];

  /// The radar discs the pins' `radarBearing` was computed for, to re-send
  /// the pins only when those change; and whether the glow is following the
  /// sweep (false once that failed on this phone).
  List<RadarDisc>? _pinsRadar;
  bool _blipOk = true;
  bool _blipping = false;

  /// At airport zoom, before the echoes show: the chip that flies to the
  /// busiest spot. Null when there's nothing to hint at.
  final ValueNotifier<_EchoHint?> _echoHint = ValueNotifier(null);
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
    try {
      _mapTier = await ref.read(mapTierControllerProvider.future);
    } on Object catch (e) {
      debugPrint('Map tier unknown, lite map: $e');
      _mapTier = MapTier.lite;
    }
    if (!mounted) return;
    await _guard.starting();
    if (!mounted) return;
    setState(() {
      _armed = true;
      _renderSettled = false;
      _mapLoaded = false;
    });
    _startLoadTimeout();
  }

  /// Gives the map [_kMapLoadTimeout] to render before this phone is
  /// treated as unable to show it.
  void _startLoadTimeout() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(_kMapLoadTimeout, () {
      // Offline, the map can't load anyway; that's not the phone's fault.
      if (!mounted || _renderSettled) return;
      if (ref.read(isOfflineProvider).value ?? false) return;
      // Locked or in the background, the map doesn't draw at all: wait
      // for the app to be on screen again instead of turning the map off.
      if (!_appInForeground) {
        _startLoadTimeout();
        return;
      }
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
    _stopFrameWatch();
    _labelView.dispose();
    _echoHint.dispose();
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
    if (_styleReady && lighting != _lightPreset) {
      unawaited(_applyLightPreset(lighting));
    }
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
              styleUri:
                  _kStandardMap ? MapboxStyles.STANDARD : MapboxStyles.DARK,
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,
              onMapLoadedListener: _onMapLoaded,
              // Not onMapIdle: the pulsing location puck redraws every
              // frame, so the map never goes idle once the user is located.
              onCameraChangeListener: (event) {
                _scheduleViewportRefresh();
                _queueLabels(event.cameraState);
              },
              onScrollListener: (_) => _stopFollowing(),
            ),
          ),
          // Map Lighting: Expo's time-of-day atmosphere tint. Standard
          // lights the map itself (see [_applyLightPreset]).
          if (!_kStandardMap)
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
                  ValueListenableBuilder<_EchoHint?>(
                    valueListenable: _echoHint,
                    builder: (context, hint, _) => hint == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: _EchoHintChip(
                              total: hint.total,
                              onTap: () => unawaited(_flyToEchoes(hint.spot)),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: ValueListenableBuilder<_LabelView>(
              valueListenable: _labelView,
              builder: (context, view, _) => Stack(
                children: [
                  if (state.pinMode == MapPinMode.counts &&
                      view.inView.isNotEmpty)
                    Positioned(
                      left: AppSpacing.md,
                      right: AppSpacing.md + 56 + AppSpacing.sm,
                      bottom: navClearance + AppSpacing.md,
                      child: AirportsInViewPanel(
                        airports: view.inView,
                        onTap: (a) =>
                            unawaited(_flyInto(a.longitude, a.latitude)),
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
      _queueLabels(_labelCamera);
    }
    if (!identical(previous?.allAirports, next.allAirports) ||
        previous?.airportCounts != next.airportCounts) {
      unawaited(_syncQuietAirports());
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
    await _syncAirportBuildings();
    if (_beacons.isNotEmpty && !_sameDiscs(_pinsRadar, _radarDiscs)) {
      _pinsRadar = _radarDiscs;
      await _setSourceData(
        _kPinsSource,
        EchoBeacons.points(_beacons, radar: _radarDiscs),
      );
    }
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

  static bool _sameDiscs(List<RadarDisc>? a, List<RadarDisc> b) =>
      a != null &&
      a.length == b.length &&
      [
        for (var i = 0; i < a.length; i++)
          a[i].lng == b[i].lng &&
              a[i].lat == b[i].lat &&
              a[i].radiusKm == b[i].radiusKm,
      ].every((same) => same);

  /// Points the lit-buildings filter at the airports near the view; only
  /// when they changed, since a new filter re-evaluates the building tiles.
  Future<void> _syncAirportBuildings() async {
    final map = _map;
    if (!_buildingsReady || map == null) return;
    final discs = _radarDiscs;
    final key = [
      for (final d in discs) '${d.lng},${d.lat},${d.radiusKm}',
    ].join(';');
    if (key == _buildingsKey) return;
    _buildingsKey = key;
    try {
      await map.style.setStyleLayerProperty(
        _kAirportBuildingsLayer,
        'filter',
        discs.isEmpty
            ? _kNoBuildings
            : [
                'any',
                // `within` only takes points and lines, not buildings.
                for (final d in discs)
                  [
                    '<=',
                    [
                      'distance',
                      {
                        'type': 'Point',
                        'coordinates': [d.lng, d.lat],
                      },
                    ],
                    d.radiusKm * 1000,
                  ],
              ],
      );
    } on Object catch (e) {
      debugPrint('Map airport buildings off: $e');
      _buildingsReady = false;
    }
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
      unawaited(_stopBlips());
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
      await _drawBlips(heading);
    } on Object catch (e) {
      _disableRadar(e);
    } finally {
      _sweepInFlight = false;
    }
  }

  /// The echoes the arm just crossed flare up: one paint update per frame,
  /// only while their glow is showing (from the airport zoom).
  Future<void> _drawBlips(double heading) async {
    final map = _map;
    if (map == null ||
        !_blipOk ||
        _beacons.isEmpty ||
        _viewZoom < _kEchoGlowFrom) {
      await _stopBlips();
      return;
    }
    try {
      await map.style.setStyleLayerProperty(
        _kPinGlowLayer,
        'circle-opacity',
        _blipOpacity(heading),
      );
      _blipping = true;
    } on Object catch (e) {
      // Decoration: the glow just stays steady.
      debugPrint('Map echo blips off: $e');
      _blipOk = false;
      await _stopBlips();
    }
  }

  /// Back to the steady glow, once, when the blips stop.
  Future<void> _stopBlips() async {
    final map = _map;
    if (!_blipping || map == null) return;
    _blipping = false;
    try {
      await map.style.setStyleLayerProperty(
        _kPinGlowLayer,
        'circle-opacity',
        _echoGlowOpacity,
      );
    } on Object catch (_) {
      // The layer is gone with its style; nothing to restore.
    }
  }

  /// Zoomed in: the airports' echoes (shown from close up), no heat.
  /// Zoomed out: no markers, only the airport clouds (and pings).
  Future<void> _syncPins() async {
    final state = ref.read(worldMapControllerProvider);
    final counts = state.pinMode == MapPinMode.counts;
    _beacons = counts ? const [] : EchoBeacons.place(state.echoNodes);
    final airports =
        counts ? AirportEchoCount.collection(state.airportCounts) : null;
    _pinsRadar = _radarDiscs;
    await _setSourceData(
      _kPinsSource,
      counts ? null : EchoBeacons.points(_beacons, radar: _radarDiscs),
    );
    _syncEchoHint();
    if (counts) await _addAirportTags(state.airportCounts);
    await _setSourceData(_kCloudSource, airports);
    await _syncPuffs();
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

  /// The airports' cloud puffs, scattered for [_viewZoom]; none close up.
  Future<void> _syncPuffs() async {
    final state = ref.read(worldMapControllerProvider);
    final counts = state.pinMode == MapPinMode.counts;
    _puffZoom = counts ? _viewZoom : null;
    try {
      await _setSourceData(
        _kPuffSource,
        counts
            ? AirportClouds.collection(state.airportCounts, zoom: _viewZoom)
            : null,
      );
    } on Object catch (e) {
      // Decoration: the airports keep their tags and taps without clouds.
      debugPrint('Map airport clouds off: $e');
    }
  }

  /// The airports without echoes, for the quiet dots and names.
  Future<void> _syncQuietAirports() async {
    if (!_quietReady) return;
    final state = ref.read(worldMapControllerProvider);
    try {
      await _setSourceData(
        _kQuietSource,
        AirportPoint.quietCollection(state.allAirports, state.airportCounts),
      );
    } on Object catch (e) {
      debugPrint('Map quiet airports off: $e');
      _quietReady = false;
    }
  }

  /// Draws the tags of airports that are new or changed (AirportTags).
  /// Decoration: if this phone can't, the map works without them.
  Future<void> _addAirportTags(List<AirportEchoCount> counts) async {
    final map = _map;
    if (!_tagsReady || map == null) return;
    try {
      await AirportTags.addTo(map.style, counts);
    } on Object catch (e) {
      debugPrint('Map airport tags off: $e');
      _tagsReady = false;
      unawaited(
        map.style
            .setStyleLayerProperty(_kTagLayer, 'visibility', 'none')
            .catchError((Object _) {}),
      );
    }
  }

  /// The "N echoes, zoom in" chip: at airport zoom with echoes loaded,
  /// pointing at the busiest spot in front of the user.
  void _syncEchoHint() {
    final state = ref.read(worldMapControllerProvider);
    final center = _viewCenter?.coordinates;
    if (state.pinMode != MapPinMode.pins ||
        center == null ||
        _viewZoom >= EchoBeacons.fadeInFrom) {
      _echoHint.value = null;
      return;
    }
    final spot = EchoBeacons.hotspot(
      state.echoNodes,
      centerLng: center.lng.toDouble(),
      centerLat: center.lat.toDouble(),
    );
    _echoHint.value =
        spot == null ? null : _EchoHint(spot, total: state.echoNodes.length);
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
        (_pingReady || (_glowReady && _glowPulseOk)) &&
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
      if (_glowReady) {
        // The glow breathes: it swells and settles once a period.
        await map.style.setStyleLayerProperty(
          _kGlowLayer,
          'circle-opacity',
          _glowOpacity(0.22 + 0.08 * math.cos(2 * math.pi * t)),
        );
      } else {
        await map.style.setStyleLayerProperty(
          _kPingRingLayer,
          'circle-radius',
          _pingRadius(radius),
        );
        await map.style.setStyleLayerProperty(
          _kPingRingLayer,
          'circle-stroke-opacity',
          _pingOpacity(0.85 * (1 - t)),
        );
      }
    } on Object catch (e) {
      if (_glowReady) {
        debugPrint('Map airport glow pulse off: $e');
        _glowPulseOk = false;
        _syncPing();
      } else {
        _disablePing(e);
      }
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
    _atmosphereTried = false;
    // Start on the user if their location arrived before the map did;
    // otherwise zoomed out (Expo's minimum) until it arrives.
    final userLocation = ref.read(worldMapControllerProvider).userLocation;
    if (userLocation != null) {
      _centerOnUser(userLocation, animated: false);
    } else {
      unawaited(
        map.setCamera(
          CameraOptions(
            zoom: _kMinZoom,
            pitch: _kStandardMap ? _kGlobePitch : 0,
          ),
        ),
      );
    }
    // Expo keeps the map flat and locks rotation when zoomed far out.
    unawaited(
      map.gestures.updateSettings(
        GesturesSettings(pitchEnabled: _kStandardMap, rotateEnabled: false),
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
          FeaturesetDescriptor(layerId: _kPinTapLayer),
          (feature, _) => unawaited(_onPinTap(feature)),
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
          FeaturesetDescriptor(layerId: _kQuietNameLayer),
          (feature, _) => unawaited(_onCloudTap(feature)),
        ),
        interactionID: 'tap-quiet-airport-names',
      )
      ..addInteraction(
        TapInteraction(
          FeaturesetDescriptor(layerId: _kQuietDotLayer),
          (feature, _) => unawaited(_onCloudTap(feature)),
        ),
        interactionID: 'tap-quiet-airport-dots',
      )
      ..addInteraction(
        TapInteraction(
          FeaturesetDescriptor(layerId: _kTagLayer),
          (feature, _) => unawaited(_onCloudTap(feature)),
        ),
        interactionID: 'tap-airport-tags',
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

    if (_kStandardMap) {
      await _configureStandard(style);
    } else if (!_atmosphereTried) {
      // The atmosphere reloads the style; the reload calls this again.
      _atmosphereTried = true;
      if (await _setAtmosphere(style)) return;
    }

    // Globe when zoomed out, as Expo and Chumme.
    await style.setProjection(
      StyleProjection(name: StyleProjectionName.globe),
    );
    await MapBadges.addTo(style);
    // The theme is decoration: if any part fails (a tileset or a GPU without
    // terrain support), the boundaries and pins must still load.
    if (!_kStandardMap) {
      try {
        await _addMapTheme(style);
      } on Object catch (e) {
        debugPrint('Map theme skipped: $e');
      }
    }

    // Our layers glow at full strength (emissive): Standard's dusk and
    // night light would otherwise dim the lime like the city around it.
    // Airport boundaries as radar scopes: tinted disc, sweep beam, grid
    // (rings, spokes, edge ticks), then a glowing outline on top.
    const radar = _kRadarColor;
    await style.addSource(GeoJsonSource(id: _kBoundarySource, data: empty));
    await style.addLayer(
      FillLayer(
        id: 'airport-boundaries-fill',
        slot: _kGroundSlot,
        fillEmissiveStrength: 1,
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
          slot: _kGroundSlot,
          fillEmissiveStrength: 1,
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
          slot: _kGroundSlot,
          lineEmissiveStrength: 1,
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
        slot: _kGroundSlot,
        lineEmissiveStrength: 1,
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
        slot: _kGroundSlot,
        lineEmissiveStrength: 1,
        sourceId: _kBoundarySource,
        lineColor: radar.toARGB32(),
        lineOpacity: 0.9,
        lineWidth: 1.5,
      ),
    );

    // The airports' own buildings, lit (3D map only, decoration).
    _buildingsReady = false;
    _buildingsKey = null;
    if (_kStandardMap) {
      try {
        await style.addSource(
          VectorSource(
            id: _kAirportBuildingsSource,
            url: 'mapbox://mapbox.mapbox-streets-v8',
            minzoom: _kAirportBuildingsMinZoom,
          ),
        );
        await style.addLayer(
          FillExtrusionLayer(
            id: _kAirportBuildingsLayer,
            sourceId: _kAirportBuildingsSource,
            sourceLayer: 'building',
            minZoom: _kAirportBuildingsMinZoom,
            filter: _kNoBuildings,
            fillExtrusionColor: _kLime.toARGB32(),
            // A shade taller than Standard's own building, so the lit shell
            // wraps it instead of flickering against it.
            fillExtrusionHeightExpression: [
              '+',
              [
                'coalesce',
                ['get', 'height'],
                6,
              ],
              1.5,
            ],
            fillExtrusionBaseExpression: [
              'coalesce',
              ['get', 'min_height'],
              0,
            ],
            fillExtrusionOpacity: 0.55,
            fillExtrusionVerticalGradient: true,
            fillExtrusionEmissiveStrength: 0.9,
          ),
        );
        _buildingsReady = true;
      } on Object catch (e) {
        debugPrint('Map airport buildings skipped: $e');
      }
    }

    // Zoomed out only: one heat cloud per airport, tuned to show from a
    // single point.
    await style.addSource(GeoJsonSource(id: _kCloudSource, data: empty));
    await style.addSource(GeoJsonSource(id: _kPuffSource, data: empty));
    _puffZoom = null;
    await style.addLayer(
      HeatmapLayer(
        id: _kCloudLayer,
        sourceId: _kPuffSource,
        heatmapWeightExpression: [
          'coalesce',
          ['get', 'heatWeight'],
          1,
        ],
        heatmapIntensityExpression: _cloudIntensity,
        heatmapRadiusExpression: _cloudRadius,
        heatmapOpacityExpression: _cloudOpacity,
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

    // The airports without echoes: dots and their tags, under the busy
    // airports' tags.
    // Decoration: if this phone can't add them, the rest still loads.
    _quietReady = false;
    try {
      await style.addSource(GeoJsonSource(id: _kQuietSource, data: empty));
      await style.addLayer(
        CircleLayer(
          id: _kQuietDotLayer,
          sourceId: _kQuietSource,
          maxZoom: AirportPinPlan.pinsMinZoom,
          circleEmissiveStrength: 1,
          circleRadiusExpression: _byZoom([(2, 1.6), (6, 2.4), (10, 3.2)]),
          circleColor: _kUi.textSecondary.toARGB32(),
          circleOpacity: 0.7,
          circleStrokeColor: Colors.black.toARGB32(),
          circleStrokeWidth: 0.6,
          circleStrokeOpacity: 0.5,
        ),
      );
      await AirportTags.addPlate(style);
      await style.addLayer(
        SymbolLayer(
          id: _kQuietNameLayer,
          sourceId: _kQuietSource,
          maxZoom: AirportPinPlan.pinsMinZoom,
          iconEmissiveStrength: 1,
          textEmissiveStrength: 1,
          iconImage: AirportTags.plateImage,
          iconTextFit: IconTextFit.BOTH,
          textFieldExpression: [
            'format',
            ['get', 'name'],
            <String, Object>{},
            '\n',
            <String, Object>{},
            ['get', 'iata'],
            <String, Object>{
              'font-scale': 0.82,
              'text-color': '#BBE40A', // _kLime
            },
          ],
          textFont: _kMapFont,
          textSizeExpression: _byZoom([(3, 9.5), (8, 11)]),
          textLetterSpacing: 0.08,
          textLineHeight: 1.3,
          textJustify: TextJustify.LEFT,
          textColor: _kUi.textPrimary.toARGB32(),
          textAnchor: TextAnchor.BOTTOM,
          textOffset: [0, -0.9],
        ),
      );
      _quietReady = true;
    } on Object catch (e) {
      debugPrint('Map quiet airports skipped: $e');
    }

    // Airport tags (AirportTags), above the airport glow, drawn by Mapbox
    // so they stay on their airport while the map moves. Zoomed out only.
    AirportTags.forgetImages();
    _tagsReady = false;
    try {
      await style.addLayer(
        SymbolLayer(
          id: _kTagLayer,
          sourceId: _kCloudSource,
          maxZoom: AirportPinPlan.pinsMinZoom,
          iconEmissiveStrength: 1,
          iconImageExpression: AirportTags.iconImage,
          iconAnchor: IconAnchor.BOTTOM,
          iconOffset: [0, AirportTags.ringInset],
          // Every airport with echoes keeps its tag, even over another;
          // the busier one is drawn on top. The quiet names still make
          // way for the tags.
          iconAllowOverlap: true,
          symbolSortKeyExpression: ['get', 'count'],
        ),
      );
      _tagsReady = true;
    } on Object catch (e) {
      debugPrint('Map airport tags skipped: $e');
    }

    // On the 3D map, the airport glow replaces the flat clouds and pings,
    // lying on the ground (pitch-aligned). If this phone can't add it, the
    // clouds and pings stay.
    _glowReady = false;
    if (_kStandardMap) {
      try {
        await style.addLayer(
          CircleLayer(
            id: _kGlowLayer,
            sourceId: _kPuffSource,
            circleEmissiveStrength: 1,
            circlePitchAlignment: CirclePitchAlignment.MAP,
            circleRadiusExpression: _glowRadius(_kGlowRadius),
            circleColorExpression: _kGlowColor,
            circleBlur: 1,
            circleOpacityExpression: _glowOpacity(0.25),
          ),
        );
        await style.addLayer(
          CircleLayer(
            id: _kGlowCoreLayer,
            sourceId: _kCloudSource,
            circleEmissiveStrength: 1,
            circlePitchAlignment: CirclePitchAlignment.MAP,
            circleRadiusExpression: _glowRadius(_kGlowCoreRadius),
            circleColorExpression: _kGlowColor,
            circleBlur: 0.4,
            circleOpacityExpression: _glowOpacity(0.7),
          ),
        );
        await style.setStyleLayerProperty(_kCloudLayer, 'visibility', 'none');
        _glowReady = true;
      } on Object catch (e) {
        debugPrint('Map airport glow skipped: $e');
      }
    }

    // Radar pings over the clouds. Decoration, and animation only: lite
    // maps skip them, and if this phone can't add them the clouds and pins
    // load without them (see [_disablePing]).
    if (!_kLiteMap && !_glowReady) {
      try {
        await style.addSource(GeoJsonSource(id: _kPingSource, data: empty));
        await style.addLayer(
          CircleLayer(
            id: _kPingRingLayer,
            sourceId: _kPingSource,
            filter: _kPingFilter,
            circleRadiusExpression: _pingRadius(_kPingMinRadius),
            circleColor: Colors.transparent.toARGB32(),
            circleStrokeColorExpression: _kPingColor,
            // Busier airports ring thicker.
            circleStrokeWidthExpression: [
              '*',
              1.4,
              [
                'coalesce',
                ['get', 'heatWeight'],
                1,
              ],
            ],
            circleStrokeOpacity: 0,
          ),
        );
        _pingReady = true;
      } on Object catch (e) {
        _pingReady = false;
        debugPrint('Map pings skipped: $e');
      }
    }

    // Echoes, from close up only: a soft glow and a floor disc lying on
    // the ground (pitch-aligned), and a wider invisible circle to tap.
    await style.addSource(GeoJsonSource(id: _kPinsSource, data: empty));
    await style.addLayer(
      CircleLayer(
        id: _kPinGlowLayer,
        sourceId: _kPinsSource,
        minZoom: _kEchoGlowFrom,
        circleEmissiveStrength: 1,
        circlePitchAlignment: CirclePitchAlignment.MAP,
        circlePitchScale: CirclePitchScale.MAP,
        circleRadiusExpression: [
          'interpolate',
          ['exponential', 2],
          ['zoom'],
          for (final (z, r) in _kEchoGlowRadius) ...[z, r],
        ],
        circleColorExpression: _kEchoColor,
        // Fully feathered: no edge, a soft cloud of light.
        circleBlur: 1,
        circleOpacityExpression: _echoGlowOpacity,
      ),
    );
    await style.addLayer(
      CircleLayer(
        id: _kPinLayer,
        sourceId: _kPinsSource,
        minZoom: EchoBeacons.fadeInFrom,
        circleEmissiveStrength: 1,
        circlePitchAlignment: CirclePitchAlignment.MAP,
        circlePitchScale: CirclePitchScale.MAP,
        circleRadiusExpression: _discRadius(null),
        circleColorExpression: _kEchoColor,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 0.8,
        circleStrokeOpacityExpression: _echoOpacity(0.7),
        circleOpacityExpression: _echoOpacity(0.95),
      ),
    );
    await style.addLayer(
      CircleLayer(
        id: _kPinTapLayer,
        sourceId: _kPinsSource,
        minZoom: EchoBeacons.fadeInFrom,
        circleRadius: EchoBeacons.tapRadiusPoints,
        circleColor: Colors.transparent.toARGB32(),
        circleOpacity: 0,
      ),
    );

    // Offers are extra: if this phone can't add their layer, the echo pins
    // and everything else still load (offers just aren't shown).
    try {
      await style.addSource(GeoJsonSource(id: _kOfferSource, data: empty));
      await style.addLayer(
        SymbolLayer(
          id: _kOfferLayer,
          iconEmissiveStrength: 1,
          textEmissiveStrength: 1,
          sourceId: _kOfferSource,
          minZoom: EchoBeacons.fadeInFrom,
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
    await _syncQuietAirports();
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

  /// The camera tilt for flying in close: tilted on the 3D city, flat on
  /// the lite map.
  double get _cityPitch => _kStandardMap ? _kCityPitch : 0;

  /// The Map Lighting preset last given to Standard, to skip repeats.
  MapTimeOfDay? _lightPreset;

  /// Mapbox Standard's look: 3D buildings and landmarks, lit by the Map
  /// Lighting preset (Standard's own presets: dawn, day, dusk, night).
  Future<void> _configureStandard(StyleManager style) async {
    _lightPreset = null;
    try {
      // A clean city, as Chumme: no street, place, POI or transit names;
      // only our own pins and labels are drawn over it.
      await style.setStyleImportConfigProperties('basemap', {
        'show3dObjects': true,
        'showRoadLabels': false,
        'showPlaceLabels': false,
        'showPointOfInterestLabels': false,
        'showTransitLabels': false,
      });
    } on Object catch (e) {
      debugPrint('Map basemap config skipped: $e');
    }
    await _applyLightPreset(
      ref.read(mapLightingControllerProvider).presetAt(DateTime.now()),
    );
  }

  /// Lights Standard for [preset]. A failure leaves the light it had.
  Future<void> _applyLightPreset(MapTimeOfDay preset) async {
    final map = _map;
    if (!_kStandardMap || map == null || preset == _lightPreset) return;
    _lightPreset = preset;
    try {
      await map.style.setStyleImportConfigProperty(
        'basemap',
        'lightPreset',
        preset.name,
      );
    } on Object catch (e) {
      debugPrint('Map light preset skipped: $e');
    }
  }

  /// Chumme's atmosphere around the globe: a dark slate rim and near-black
  /// space with faint stars. The plugin has no fog setter, so the loaded
  /// style's JSON gets the `fog` and is loaded back; that reloads the style.
  /// False when it couldn't be set: the map goes on with Mapbox's default.
  Future<bool> _setAtmosphere(StyleManager style) async {
    try {
      final json = jsonDecode(await style.getStyleJSON());
      if (json is! Map<String, dynamic>) return false;
      json['fog'] = _kAtmosphere;
      await style.setStyleJSON(jsonEncode(json));
      return true;
    } on Object catch (e) {
      debugPrint('Map atmosphere skipped: $e');
      return false;
    }
  }

  /// Map theming over dark-v11 (the lite map): no base labels, Chumme's
  /// land/water palette, terrain, and Expo's 3D buildings from zoom 13.
  ///
  /// On low-end phones ([_kLiteMap]) terrain and 3D buildings are skipped.
  Future<void> _addMapTheme(StyleManager style) async {
    // No street, place or POI names, as on Standard. This runs before our
    // own layers are added, so every symbol layer here is the style's.
    for (final layer in await style.getStyleLayers()) {
      if (layer == null || layer.type != 'symbol') continue;
      try {
        await style.setStyleLayerProperty(layer.id, 'visibility', 'none');
      } on Object catch (e) {
        debugPrint('Map label skipped ${layer.id}: $e');
      }
    }

    // Repaints the style's own layers, so the coastlines stay exactly as
    // Mapbox cut them and nothing extra is drawn. One missing layer only
    // leaves that layer in its stock color.
    for (final (layer, property, color) in _kBasemapPalette) {
      try {
        await style.setStyleLayerProperty(layer, property, color);
      } on Object catch (e) {
        debugPrint('Map palette skipped $layer: $e');
      }
    }
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
      pitch: _cityPitch,
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
          pitch: _cityPitch,
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
    _startFrameWatch();
    _scheduleViewportRefresh();
  }

  // --- Device ladder: frame watch -------------------------------------------

  /// On the 3D map, frame times are watched; if they stay mostly below
  /// ~30 fps (FrameBudgetMonitor), this phone gets the lite map from the
  /// next launch. Once per run, then the watch stops.
  TimingsCallback? _frameWatch;

  void _startFrameWatch() {
    // Debug builds are slow by nature: only real builds may judge a phone.
    if (kDebugMode || !_kStandardMap || _frameWatch != null) return;
    final monitor = FrameBudgetMonitor();
    void watch(List<FrameTiming> timings) {
      for (final t in timings) {
        if (monitor.add(t.totalSpan)) {
          debugPrint('Map 3D too slow here: lite map from next launch');
          unawaited(ref.read(mapTierControllerProvider.notifier).markTooSlow());
          _stopFrameWatch();
          return;
        }
      }
    }

    _frameWatch = watch;
    SchedulerBinding.instance.addTimingsCallback(watch);
  }

  void _stopFrameWatch() {
    final watch = _frameWatch;
    if (watch != null) SchedulerBinding.instance.removeTimingsCallback(watch);
    _frameWatch = null;
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
        GesturesSettings(
          rotateEnabled: camera.zoom > _kGestureLockZoom,
          pitchEnabled: _kStandardMap,
        ),
      ),
    );
    // Zoomed out, a steep tilt looks across the horizon and makes the 3D
    // map draw a huge stretch of terrain (measured: ~35% janky frames).
    // The globe view settles back to a gentle tilt.
    if (_kStandardMap &&
        camera.zoom < _kHeatFadeEnd &&
        camera.pitch > _kGlobePitch + 1) {
      unawaited(
        map.easeTo(
          CameraOptions(pitch: _kGlobePitch),
          MapAnimationOptions(duration: 500),
        ),
      );
    }
    final view = MapViewBounds.normalize(
      west: bounds.southwest.coordinates.lng.toDouble(),
      south: bounds.southwest.coordinates.lat.toDouble(),
      east: bounds.northeast.coordinates.lng.toDouble(),
      north: bounds.northeast.coordinates.lat.toDouble(),
      centerLng: camera.center.coordinates.lng.toDouble(),
    );
    _viewCenter = camera.center;
    _viewZoom = camera.zoom;
    final puffZoom = _puffZoom;
    if (puffZoom != null && (puffZoom - camera.zoom).abs() > 0.3) {
      unawaited(_syncPuffs());
    }
    _syncEchoHint();
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

  /// One echo under the finger opens its card; several (a crowd on one
  /// spot) open the list of them.
  Future<void> _onPinTap(FeaturesetFeature feature) async {
    final props = feature.properties;
    final id = (props['id'] ?? feature.id?.id)?.toString();
    if (id == null || id.isEmpty) return;
    final type = props['type']?.toString() ?? 'terminal_echo';
    final tapped = _beacons.where((b) => b.node.id == id).firstOrNull;
    final map = _map;
    if (tapped != null && map != null) {
      final zoom = (await map.getCameraState()).zoom;
      final echoes = EchoBeacons.near(
        _beacons,
        lng: tapped.lng,
        lat: tapped.lat,
        meters: EchoBeacons.tapRadiusPoints *
            EchoBeacons.metersPerPoint(zoom, tapped.lat),
      );
      if (!mounted) return;
      if (echoes.length > 1) {
        await _openStack(echoes);
        return;
      }
    }
    await _openPin(id, type);
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
      'circle-radius',
      _discRadius(id),
    );
  }

  /// Flies from an airport's cloud into the airport, where its pins load.
  Future<void> _onCloudTap(FeaturesetFeature feature) async {
    final coords = feature.geometry['coordinates'];
    if (coords is! List || coords.length < 2) return;
    await _flyInto(
      (coords[0]! as num).toDouble(),
      (coords[1]! as num).toDouble(),
    );
  }

  /// Flies from the zoomed-out map into an airport, where its pins show.
  Future<void> _flyInto(double lng, double lat) async {
    final map = _map;
    if (map == null) return;
    setState(() => _following = false);
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: _kAirportZoom,
        pitch: _cityPitch,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  /// From the airport-zoom chip: down to the busiest spot, where the
  /// echoes show.
  Future<void> _flyToEchoes(EchoHotspot spot) async {
    final map = _map;
    if (map == null) return;
    setState(() => _following = false);
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(spot.lng, spot.lat)),
        zoom: _kEchoesZoom,
        pitch: _cityPitch,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  // --- Airport labels (zoomed out) ------------------------------------------

  /// Lays the labels out for [camera] (null: the last one seen). While an
  /// update is running only the newest camera is kept, so a fast pan costs
  /// one projection call at a time, never a backlog.
  void _queueLabels(CameraState? camera) {
    final next = camera ?? _labelCamera;
    if (next == null) return;
    _labelCamera = next;
    if (_labelsInFlight) return;
    unawaited(_runLabels());
  }

  Future<void> _runLabels() async {
    _labelsInFlight = true;
    try {
      CameraState? done;
      while (_labelCamera != null && !identical(_labelCamera, done)) {
        done = _labelCamera;
        await _layoutLabels(done!);
      }
    } finally {
      _labelsInFlight = false;
    }
  }

  Future<void> _layoutLabels(CameraState camera) async {
    final map = _map;
    final state = ref.read(worldMapControllerProvider);
    if (map == null ||
        !_styleReady ||
        state.pinMode != MapPinMode.counts ||
        state.airportCounts.isEmpty) {
      _labelView.value = const _LabelView();
      return;
    }
    final center = camera.center.coordinates;
    final screen = MediaQuery.sizeOf(context);
    final maxAngle = AirportVisibility.viewAngleDeg(
      camera.zoom,
      halfDiagonal: math.sqrt(
            screen.width * screen.width + screen.height * screen.height,
          ) /
          2,
    );
    final candidates = [
      for (final a in state.airportCounts)
        if (AirportVisibility.facesCamera(
          lat: a.latitude,
          lng: a.longitude,
          centerLat: center.lat.toDouble(),
          centerLng: center.lng.toDouble(),
          maxAngleDeg: maxAngle,
        ))
          a,
    ]..sort((a, b) => b.count.compareTo(a.count));
    final ranked = candidates.take(_kLabelCandidates).toList();
    final List<ScreenCoordinate?> points;
    try {
      points = await map.pixelsForCoordinates([
        for (final a in ranked)
          Point(coordinates: Position(a.longitude, a.latitude)),
      ]);
    } on Object catch (e) {
      debugPrint('Map airports in view skipped: $e');
      return;
    }
    if (!mounted) return;
    final inView = <AirportEchoCount>[
      for (var i = 0; i < ranked.length && i < points.length; i++)
        if (points[i] case final p?
            when p.x >= 0 &&
                p.y >= 0 &&
                p.x <= screen.width &&
                p.y <= screen.height)
          ranked[i],
    ];
    _labelView.value = _LabelView(inView: inView);
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

/// The heat hands over to pins across the last zoom step before pins mode
/// (Chumme's heat-to-dots fade): blobs shrink and fade out instead of
/// switching off at once.
const double _kHeatFadeEnd = AirportPinPlan.pinsMinZoom;
const double _kHeatFadeStart = _kHeatFadeEnd - 1;

/// Chumme's kernel, per puff (AirportClouds): grows while the heat is
/// regional, then shrinks into the handover so neighbouring airports pull
/// apart instead of merging.
const List<Object> _cloudRadius = [
  'interpolate', ['linear'], ['zoom'], //
  0, ['*', 11, _cloudScale],
  3, ['*', 20, _cloudScale],
  5, ['*', 26, _cloudScale],
  _kHeatFadeStart, ['*', 21, _cloudScale],
  _kHeatFadeEnd, ['*', 12, _cloudScale],
];

/// Hotter as you zoom in, so spread-out airports stay legible (Chumme),
/// but kept low: the user wants a faint haze, not a burning blob.
const List<Object> _cloudIntensity = [
  'interpolate', ['linear'], ['zoom'], //
  0, 0.4,
  4, 0.8,
  _kHeatFadeStart, 1.0,
  _kHeatFadeEnd, 1.2,
];

/// A faint haze (the user asked for barely there), gone by the time the
/// pins take over.
const List<Object> _cloudOpacity = [
  'interpolate', ['linear'], ['zoom'], //
  0, 0.4,
  _kHeatFadeStart, 0.35,
  _kHeatFadeEnd, 0,
];

/// Chumme's heat ramp (`utils/heatRamp.ts`): a cyan aura through lime,
/// yellow, coral and scarlet to a crimson core.
const List<Object> _cloudColor = [
  'interpolate', ['linear'], ['heatmap-density'], //
  0, 'rgba(0,0,0,0)',
  0.12, 'rgba(0, 220, 255, 0.55)',
  0.28, 'rgba(46, 213, 115, 0.85)',
  0.48, '#FFD32A',
  0.68, '#FF6B35',
  0.88, '#FF3838',
  1, '#FF1744',
];

// --- Overlays --------------------------------------------------------------

/// Expo's `TerminalMapSearchBar`: opens airport search.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kUi.glassStrong,
      shape: StadiumBorder(side: BorderSide(color: _kUi.hairline)),
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
                color: _kUi.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'SEARCH AIRPORT...',
                  maxLines: 1,
                  style: TextStyle(
                    color: _kUi.textMuted,
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
        color: _kUi.glassStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: offline ? colors.error.withValues(alpha: 0.5) : _kUi.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (offline)
            Icon(Icons.cloud_off_rounded, size: 15, color: colors.error)
          else
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _kUi.textSecondary,
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            offline ? 'NO INTERNET — SHOWING SAVED DATA' : 'SLOW CONNECTION…',
            style: TextStyle(
              color: offline ? colors.error : _kUi.textSecondary,
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
        color: _kUi.glassStrong,
        shape: CircleBorder(side: BorderSide(color: _kUi.hairline)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 56,
            child: Icon(icon, color: _kUi.textPrimary, size: 22),
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

/// The airport-zoom hint: echoes are loaded but only show from close up.
class _EchoHint {
  const _EchoHint(this.spot, {required this.total});

  /// Where tapping the chip flies.
  final EchoHotspot spot;

  /// Echoes loaded for the airports in view.
  final int total;
}

/// "12 ECHOES HERE · ZOOM IN": tapping flies down to where they are.
class _EchoHintChip extends StatelessWidget {
  const _EchoHintChip({required this.total, required this.onTap});

  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kUi.glassStrong,
      shape: StadiumBorder(
        side: BorderSide(color: _kLime.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _kLime,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kLime.withValues(alpha: 0.7),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$total ${total == 1 ? 'ECHO' : 'ECHOES'} HERE · ZOOM IN',
                style: TextStyle(
                  color: _kUi.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.zoom_in_rounded, size: 16, color: _kLime),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the in-view panel lists: the airports on screen, busiest first.
class _LabelView {
  const _LabelView({this.inView = const []});

  final List<AirportEchoCount> inView;
}
