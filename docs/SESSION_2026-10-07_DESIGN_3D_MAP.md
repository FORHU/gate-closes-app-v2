# Session 2026-10-07: Chumme design, 3D dusk map, device ladder

## Resume here (2026-10-09)

> Superseded: start from `NEXT_SESSION.md`. Kept as the record of
> 2026-10-07/08.

**The 2026-10-07 plan, status at the end of 2026-10-08:**

| Planned | Status |
| :--- | :--- |
| Human-sized echo pins, only from a close zoom | **Done**: z16, floor disc (column tried, rejected as "a tower"), hint chip flies in, finger taps, crowd → stack list |
| Country tap → its airports | **Done** (2026-10-08, seen on the realme): Mapbox `country-boundaries-v1` tileset (no asset), invisible hit layer + lime outline below z10.5, `CountryAirportsSheet` busiest first → fly in; `AirportPoint.countryCode`/`inCountry` |
| Live clouds (weather) | **Dropped** by the user |
| Land/water color tuning on Standard | **Done**: user picked option C of three shown on the Xiaomi (current blue-grey / near-black night / green): `_kStandardColors` colorWater #1D4A70, colorLand #4C7656, colorGreenspace #5C8F62 (first try #14324D/#2F4A36/#3B5E40 read near-black at dusk close up), each set separately. `getStyleImportSchema` isn't wired on Android in plugin 2.25 |
| realme gets the lite map | **Done**: realme opens the lite map, chip, radar, country tap work. Fix: lite has no sweep, so echo/offer glow cores now glow steadily there (echo 0.6, offer 0.3) instead of never showing |
| Airport search by code/city | **Open** (name search accepted for now; needs API work) |
| Radar sweep cost (~15 GeoJSON sends/s) | **Measured + fixed** (Xiaomi, profile, MNL z13, 2 runs each): glow every sweep frame = 17–29% janky idle / 24–29% panning; glow off = 5% / 7–20%; glow every 2nd frame (`_sweepFrame`, rise 26°) = **3.5–3.9% / 10%**, looks the same. The sweep itself is cheap |

**Added on 2026-10-08 (not in the plan):** airport tags anchored to the
map and on every airport, the far-side label bug, green radar, radar
detection glow (dark halo + lit core) for records and offers, cloud heat
(tight per airport, faint), airport glow instead of the light-beam
towers, hidden vouchers/gifts/ads (banner, offer indicator and badge
removed), lock-screen render-guard fix, `iata` in the airport GeoJSON.

adb on the realme: each `input` call takes ~1.3 s, so quick-zoom needs
`input tap X Y & sleep 0.12; input motionevent DOWN…` in one shell call.

**Not checked on a phone:** several echoes on one spot (spread + stack
sheet; no such data), the other echo type colors, an offer's dot at z16
(its spot is random per traveler per day), perf after the glow cores.

**All committed on `feat/design-3d-map` (app-v2, not pushed)**, analyze
clean, 245 tests pass. One commit per feature:

1. `60818b6 feat(theme): new design language in the Gate Closes lime`
2. `4ed2742 feat(map): device ladder picks the 3D or lite map`
3. `5c167cd feat(map): human-sized echoes, spread and radar bearing`
4. `51cc00a feat(map): airport clouds instead of circles`
5. `eba5e75 feat(map): tags for every airport and the airports-in-view panel`
6. `fe8e84d feat(map): Standard 3D at dusk with radar, clouds, tags and echoes`
   (the map page ties 3–5 together, so it lands last; also the render
   guard fix)
7. docs commit (this file + HANDOFF)

Each commit was checked out alone and analyzed. API: `039d028
feat(airport): include the IATA code in the map GeoJSON` on
`feat/airport-offers-and-access` (not pushed). API full suite: 247 pass
under vitest; `npm test` (mocha, Node 24) cannot load the ESM `kdbush`
(pre-existing, not from this work). `AirportRadar.area` was dropped
(unused since the lit buildings use a `distance` filter).

**After the commits (2026-10-08 afternoon, uncommitted):** the user's
"Map Content & Heat Map" spec:
- Heat: tight zoomed out, growing in (`AirportClouds.zoomScale` 0.35→1
  by z9; heat kernel 4→17 pt; 3D halo 4→15 pt), each airport its own.
- Radar glow: dark rich shade of the record's color (`_kEchoGlowColor`),
  human-sized feathered halo (5 pt at z10.5 → 14 pt at z16), nothing
  between detections (rest 0); darker and with a lit core below.
- **Detection glows** (user: "darker when detected", then "it's like a
  fading color", "make it glow when detected"): the halo is ~40% darker
  (echo #455A00/#11506A/#6E4610/#591331, offer #5A4100/#451A54/#672C10)
  at peak 0.9, and a small core (0.4× the halo, blur 0.6) in the item's
  own true color lights up only at detection (`echo-blip-core`,
  `offer-blip-core`, peak 0.85, 0 between passes). Dark halo + lit core
  reads as glowing. Costs two more `circle-opacity` updates per sweep
  frame (four with offers); not measured.
- **Offers are hidden discoveries, like records** (user: "the voucher
  must be like the records so it's hard to detect"): `OfferMapFeatures`
  carries `group` (`OfferGroup` voucher/gift/ad by kind name) and
  `radarBearing`; close up (z15.9+) an offer is a small faint dot (0.45,
  0.75× an echo disc) in its group color (voucher #C9A227, gift #A35BC0,
  ad #D9733A) with a finger-sized tap target → OfferSheet; the radar
  glow (`offer-glow`, dark group colors) reveals it from the airport
  zoom. The orange offer badge (asset + MapBadges.offer) is deleted.
- **Removed** (user's choices): the offer banner, and the airport offer
  indicator + list sheet built earlier the same afternoon (they gave the
  hidden offers away). `offerCard`/card offers are no longer kept: an
  admin "card" placement has no spot, so it doesn't show on the map.
  OfferSheet opens on the root navigator (the nav bar covered it).
- Seen on the Xiaomi at MNL z13: no indicator/banner; echo and offer
  glows small and dark behind the arm. The offer dot at z16 was not
  found on screen (its spot is random per traveler per day).

**Next:** commit the afternoon's work when the user says "commit"
(suggested: `feat(map): tighter cloud heat`, `feat(map): radar detection
glow with a lit core`, `feat(map): hidden vouchers, gifts and ads`,
`docs`); then push/PR when the user says so; realme (lite map on a real weak
phone) ✓; country tap ✓; crowd test (several echoes on one spot); other echo
type colors; radar sweep cost (re-sends GeoJSON ~15×/s, unmeasured).

**2026-10-08: human-sized echoes built and tested on the Xiaomi.**
Decided with the user: show zoom **16**, airport-stage **hint chip that
flies in** ("N ECHOES HERE · ZOOM IN" → busiest spot at z16.6), look =
**glowing floor disc only**. A light column on each echo was built and
**removed**: the user said it looked "like a tower" (tried 28 pt tall to
rise above roofs, then 10 pt / 2 m; both rejected). Don't bring it back.
Code: `domain/entities/echo_beacons.dart` (+ test): sunflower spread 2.5 m
on shared spots, disc ≥7 pt → ~1.2 m close up (exponential by zoom), glow
×3 at 0.7, `near()` for finger taps (>1 hit → stack sheet), `hotspot()`.
Page: clustering + cluster badges removed; glow/disc/tap circle layers;
offers also only from z15.9. Suggested commit 7: `feat(map): human-sized
echoes from close up`.
**Tested (profile, Baguio + MNL):** chip, fly-in, discs over roofs and on
the airfield, tap opens the card. Panning close up (with the column then):
12% janky, p90 15 ms. In landscape the offer banner covers the center.
**Not tested yet:** a crowd on one spot (spread + stack sheet; no shared
spots in today's data), other echo type colors, the lite map (realme).

**Also 2026-10-08 (tested on the Xiaomi):**
- **Label bug fixed:** a "JFK · 2 ECHOES" tag showed over Luzon at zoom
  ~7 (data was right; Mapbox projects far-side points onto the screen).
  `AirportLabelLayout.viewAngleDeg(zoom)` now culls label candidates at
  every zoom (was only below z5). The user described it as "the airport
  tag moves to the pinned location and then returns".
- **Radar blips (user's idea):** when the sweep arm crosses an echo its
  glow flares, then fades over 120° of the turn to 0.3. Echoes inside a
  radar disc get `radarBearing` (EchoBeacons.points); one
  `circle-opacity` update per sweep frame, only close up. Glow halo now
  ×4.5. Steady glow when the sweep isn't running (lite map).
- **Light beams removed** (user: "towers" zoomed out too). Replaced by an
  **airport glow**: two pitch-aligned circle layers on the cloud source
  (blurred halo 14–26 pt + core 3.5–6 pt, × cloudScale), color = heat
  ramp by ln(count) or lime when fresh, breathes via `circle-opacity` on
  the ping clock, fades with the heat into the radar zoom. No per-zoom
  rebuild any more. `airport_beams.dart` + test deleted;
  `metersPerPoint` moved to EchoBeacons.
- **"As long as the radar glows yellow it must detect the echoes"** (user):
  the echo **glow** now shows from the airport zoom (10.5, where circles,
  radar and echo data start), not only from 16; halo 9 pt → 31 pt at z16
  (`_kEchoGlowRadius`). Blips run at all those zooms. The solid disc and
  taps still start at 16; the hint chip stays. Seen on the Xiaomi at MNL
  z13: 12 echoes glow inside the radar and flare right behind the arm.
- **Airport tags anchored to the map** (user: the marker must stay on the
  airport's coordinates and move with the map, not sit fixed on screen).
  The Flutter overlay (re-projected per camera change) lagged a swipe.
  Now `presentation/airport_tags.dart` draws each tag (glass plate,
  Poppins name + "MNL · 12 ECHOES", leader, ring) into an image per
  airport (redrawn only when name/count change) and a SymbolLayer
  `airport-tags` on the cloud source places it (`icon-anchor` bottom,
  offset so the ring is on the airport, `symbol-sort-key` −count, max
  zoom 10.5). Mapbox handles overlap (busier wins) and the globe's far
  side. Tap → fly in. Lost: the old fan-out of plates to free spots
  (AirportLabelLayout.place) — deleted with `airport_labels.dart`; the
  in-view panel keeps `AirportVisibility` (facesCamera/viewAngleDeg).
  Seen on the Xiaomi: during a swipe the MNL tag moves with the map, ring
  on the airport glow. (adb tip: DOWN/MOVE/UP as separate `adb shell`
  calls jams Mapbox's gestures until the app restarts; use one
  `input swipe`.)

- Branch renamed `feat/design-3d-map` (no "Chumme" in names).
- **All airports on the map** (user: "we are going to make a lot of ads
  promotion to all working airports"). API: `/airport/geojson` features
  now carry `iata` (repo projection + service, cache key `v2`, test
  updated; **uncommitted in gate-closes-api** on
  `feat/airport-offers-and-access`). App: `AirportPoint.fromBoundaries`
  (+ test) → `WorldMapState.allAirports`; zoomed out (< 10.5) every
  airport without echoes gets a dot and a **glass tag** (name + IATA)
  from ONE shared 9-slice image (`AirportTags.plateImage`,
  `icon-text-fit`) — 3,478 per-airport images would not fit in memory.
  Echo tags (per-airport images, leader + count) always show
  (`icon-allow-overlap`, busier on top); quiet tags yield to them and to
  each other, so at globe zoom only the ones that fit show, all appear
  closer in. Tap a quiet tag/dot → fly in.
- **Heat as clouds, faint** (user: "look like clouds not circled", "too
  intense, like 1%", "soft and feathered like light clouds"):
  `AirportClouds` (+ test) scatters 10 puffs per airport (seeded by IATA,
  1.6× wider than tall, in screen points, rebuilt when zoom moves > 0.3)
  into `airport-puff-source`; the lite heatmap and the 3D glow halo draw
  from it (core/tags/taps stay on the airport point). Heat opacity
  0.4→0.35, intensity halved; 3D halo 0.25 (breathing 0.22±0.08), core
  0.7.
- **Soft radar blips** (user): echo glow fully feathered (blur 1, halo
  12→40 pt), fades in over 18° after the arm crosses to 0.55, eases out
  over 180° to 0.06; steady glow outside a radar 0.3.
- **Lite map checked on the Xiaomi** (flag `map_3d_too_slow` set via
  run-as, then removed): all features work (tags, quiet tags, heat, radar,
  echo glows/discs). realme itself still untested.
- **Bug fixed:** opening the map with the phone locked tripped the render
  guard ("Map isn't available"); the 25 s load timeout now waits while the
  app isn't in the foreground (`_startLoadTimeout`).
- **Radar is green** (user): `_kRadarColor` #2ED573 (the heat ramp's
  green) for circles, sweep and grid. Lit buildings and the hint chip keep
  the lime via a new `_kLime`. Seen on the Xiaomi at MNL.

**Open next (in the agreed order):**
- **NEW (user's plan, discussed end of day): human-sized echo pins.**
  Echoes (records) sized in meters, about a person standing in the
  terminal, to stop clutter and give a cleaner UX/UI. **They only show
  from a close "desired" zoom; no pins before it** (no clusters at
  airport zoom). Stages: globe/region = towers + labels; airport = radar
  + lit buildings, no pins; close-up = human-sized echoes. Proposed (not
  yet confirmed): pin = glowing floor disc (column later dropped), colored by
  echo type; tap area stays finger-sized; a dense spot opens the stack
  list; echoes at the same rounded point (~110 m) spread slightly so they
  read as a crowd; lite map = flat floor dots. Open: exact show-zoom, and
  the airport-stage hint ("12 echoes · zoom in") + flying in straight to
  close-up (suggested). Prototype on the Xiaomi at Manila first.
- Country tap → that country's airports (invisible country hit layer,
  Chumme `CountryHitLayer`; needs a countries GeoJSON asset).
- ~~Live clouds (OpenWeatherMap)~~ **dropped**: the user doesn't want
  weather on the map ("we are not creating a weather map"). Chumme only
  used it as globe decoration.
- Land/water color tuning on Standard (its color config), atmosphere is a
  nice-to-have.
- Check the **realme** gets the lite map (32-bit → lite); not tested today.
- Airport search only matches the airport **name** ("Ninoy" finds MNL,
  "MNL"/"Manila" find nothing). User is fine with name search for now;
  code/city search needs API work (no city field in the DB).
- Possible perf work: radar sweep re-sends its GeoJSON ~15×/s (unmeasured).

## Decisions made with the user today

- **Design = Chumme's design language, Gate Closes lime kept** (not pink).
  Copy first, upgrade later. Theme first, then map, then screens.
- **Map = Mapbox Standard, dusk look** (user's references: Barbican /
  Dotonbori 3D dusk). Realtime lighting changed: **dusk 05–19, night
  19–05** (dawn/day still selectable as fixed presets).
- **No street/place/POI/transit names** on the map (like Chumme).
- **No flat 2D effects on the 3D map**: light beams instead of heat blobs,
  breathing glow instead of rings. Flat heat stays as the lite fallback.
- **Lit airport buildings: keep** (measured: no added lag).
- **Device ladder now** (user's choice after measuring zoomed-out jank).
- Repo: app-v2 moved to `FORHU/gate-closes-app-v2`, `personal` remote
  (rmValdez) removed. `main` there = `03e0955` (scale bar fix).
- API `main` on FORHU = `8e03b9c` (offers/roles/airports pushed today);
  production is not live yet ("devs not done"); it returned 503 before
  and after the push.

## What was built

### Theme (Chumme `modules/chumme-ds` → `lib/theme`)
- `GateColors`: maroon layers (`#120a0d` bg, `#201519` surface, `#2a1b20`
  elevated, `#3a232a` pressed), glass/glassStrong, hairline, borderStrong,
  `accentWarm` (ember `#ff7a45`), fog text; lime accent unchanged.
- Poppins (copied from Chumme `assets/fonts`, OFL), Chumme type scale;
  radii 10/16/22, card 16; deeper shadows, `premiumGlow`, `buttonGlow`,
  `brandButton` gradient, `cardSheen`.
- `GlassCard` = Chumme `GlassSurface` (unclipped shadow, hairline, sheen,
  `holo` stripe+glow). `AmbientBackground` = two lime blooms.
- Sheets/dialogs/snackbars/dividers themed (`surface_theme.dart`).
- Bug fixed: `colors.border.withValues(alpha: x)` **sets** alpha (made 50%
  grey borders); replaced with tokens in profile/onboarding/echo thread.
- Tab pages (feed, connections, profile) have transparent scaffolds so
  MainLayout's ambient background shows.
- Nav "Connections" label wrapped with Poppins → FittedBox one line.
- **The user's Xiaomi had Dark mode OFF** (Settings → General). The new
  look is the dark theme; light theme kept as is. Dark-only is undecided.

### Map (`world_map_page.dart`)
- `_mapTier` (device ladder) → `_kStandardMap` / `_kLiteMap` getters.
- Standard: `setStyleImportConfigProperties('basemap', {show3dObjects,
  showRoadLabels:false, showPlaceLabels:false, showPointOfInterestLabels:
  false, showTransitLabels:false})`, `lightPreset` from Map Lighting
  (`_applyLightPreset`), no tint overlay.
- Lite (dark-v11): Chumme palette repaint (land/landuse/park/water),
  atmosphere via `getStyleJSON`+`fog`+`setStyleJSON` (one style reload;
  `_atmosphereTried`), base symbol layers hidden.
- Our layers: radar/boundaries in `slot: 'middle'`; **emissive strength 1**
  on our fills/lines/icons (Standard dusk/night dims them otherwise).
- Pitch: fly-ins tilt 55°, globe opens at 35°, pitch gesture always on
  (3D); zoomed out (< pins zoom) a steeper tilt eases back to 35°.
- Overlays use `GateColors.dark` (`_kUi`) since the map is always dark.
- Scale bar off, compass below the search pill (committed earlier today).

### Zoomed-out effects
- **Light beams** (`AirportBeams`): 16-gon fill-extrusion per airport,
  3.5 pt radius, 24–110 pt tall (log of echo count, full at 50), sized for
  the current zoom (rebuilt when zoom changes > 0.2), color = Chumme heat
  ramp by activity, lime when fresh (echo < 20 min). Breathes via
  `fill-extrusion-emissive-strength` on the ping clock. Heat cloud layer
  hidden when beams exist (its tap layer stays).
- Lite fallback: heat in Chumme's ramp, kernel/intensity ramps, fades out
  over the last zoom step before pins (10.5); pings only for busy (≥3) or
  fresh airports, lime/coral.

### Lit airport buildings (3D only)
- Extra `FillExtrusionLayer` on `mapbox.mapbox-streets-v8` `building`,
  from zoom 13, lime, height+1.5 m, opacity 0.55, emissive 0.9.
- Filter: `any` of `distance(point) <= radius` per nearby radar disc.
  **`within` does not work** (Mapbox only supports points/lines there).
  Empty filter must be `['boolean', false]` (not `['==',1,0]`, read as a
  legacy filter → "filter property must be a string").
- Filter only re-set when the nearby airports change (`_buildingsKey`).

### Labels + panel (zoomed out)
- `AirportLabelLayout` (pure, tested): ranked candidates, ring of spots
  (up, ±35°, ±65° at lift 64 and ×1.6, then below as last resort), no
  plate overlap, anchors kept clear, inside `_labelArea`; `facesCamera`
  hides the far side of the globe below zoom 5.
- `AirportLabels`: glass plate (name minus "International Airport",
  "IATA · N ECHOES"), glowing lime leader line + ring; width estimated
  (title×9.4, meta×7). `AirportsInViewPanel`: "AIRPORTS IN VIEW · N",
  top airport collapsed, up to 20 open; tap → `_flyInto`.
- Projection: one `pixelsForCoordinates` per update, newest camera only
  (`_queueLabels`/`_runLabels`), from `onCameraChangeListener`'s
  `cameraState`. Labels/panel redraw via `ValueNotifier<_LabelView>`.

### Device ladder
- `MainActivity.kt` channel `gate_closes/device` → `mapCapabilities`
  {totalRamMb, lowRam, sdk}. `DeviceCapabilitiesSource` (unknown fields
  on iOS/tests). `MapTierPolicy.decide`: lite if 32-bit, RAM < 5000 MB,
  Android low-RAM flag, SDK < 29, or measured too slow.
- `MapTierController` (AsyncNotifier) resolves before the map arms.
- `FrameBudgetMonitor` (300 frames, ≥50% over 33 ms) via
  `addTimingsCallback` on the 3D map, **not in debug builds**; verdict
  stored as `map_3d_too_slow` → lite from the next launch.
- Test helper overrides the device source (else the map never arms).
- Xiaomi (7.3 GB, 64-bit, Android 13) → 3D; not flagged.

## Measurements (Xiaomi, gfxinfo while panning by adb swipes)
- **Debug builds are useless for perf** (noisy, slow). Use
  `flutter build apk --profile --dart-define-from-file=.env.dev`.
- Zoomed in at an airport (profile): ~1–9% janky, buildings on or off.
- Zoomed out (profile): 3D Standard 22–37% janky (p90 24–40 ms); labels
  off or breathing off made no difference; dark/lite map 13–21% (p90
  16 ms). Cost = Standard's zoomed-out rendering → device ladder.

## Phone / tooling notes
- Xiaomi Redmi Note 11 Pro 5G `63ffc6dec2f4` (Adreno 619) is the 3D
  reference; realme `0151312S28102753` (32-bit, PowerVR) is lite.
- The Xiaomi keeps turning Wi-Fi off; it must be on the PC's network
  (PC `192.168.1.20`, API `:3001`).
- Zoom out by adb (no pinch): one shell call
  `input tap X Y; input motionevent DOWN X Y; MOVE …; UP …` (quick-zoom).
  Tap away from airports or the tap flies into one.
- Map search: tap the pill (540,177 px), `input text "Ninoy"`, then use
  `uiautomator dump` (with `MSYS_NO_PATHCONV=1`) to find result bounds.
- `run-as com.reeethepuffer.gateclosesapp cat
  shared_prefs/FlutterSharedPreferences.xml` shows stored flags
  (`flutter.map_3d_too_slow`).
- The API was started in this session's background (`npm run dev`, 3001);
  it stops with the session: restart it in its own window tomorrow.
- Staff test password and DB URI-in-logs are open security items (see
  `SESSION_2026-10-06_OFFERS_RBAC.md` / today's chat): FORHU repos are
  public; the seeder has `GateCloses123!`; Node's DEP0170 warning prints
  the Mongo URI with password. User paused that fix ("ok for now").
