# Session 2026-10-01 — map fixes, radar circles, zoomed-out pins

Pick-up notes for the next session. Read `HANDOFF.md` for the wider
project state.

**Committed 2026-10-05 (local, not pushed):** app `9871df9` (A),
`93217c7` (D), `59bb98b` (B + E); API `0888f77` (C), `9c7040a` (docs).
Each app commit passed analyze + 170 tests on its own. Device checks for
D (Pacific view) and B (sweep look) are still open.

**Next feature (agreed 2026-10-05): load pins per airport.** Zoomed in
(zoom 7+): `GET /map?airport=MNL`, cached, refreshed by the existing
Socket.IO airport room (`terminal_echo:join_airport` →
`terminal_echo:changed`). Zoomed out: `GET /map/counts` (echoes per
airport), one bubble per airport, short cache. Also enforce the radius
on the server: `createTerminalEcho` computes `insideRadius` but saves
the echo anyway. All 21 echoes in the DB have an `airportIata`.

**Built 2026-10-05 (committed 2026-10-06; the switch zoom later moved from 7 to 10.5):**
- API: `GET /terminal-echo/map?airport=MNL` (uses `idx_airportIata_createdAt`,
  max 100), `GET /terminal-echo/map/counts` (GeoJSON point per airport at
  the airport's location), `POST /terminal-echo` answers **422** outside
  every radius (`EchoOutsideAirportError`). `npm run dev` now watches
  `src` (`--watch *.ts` never reloaded on Windows). tsc/eslint clean,
  205 tests. Checked live: counts 7 airports, `?airport=mnl` 12 pins.
- App: `AirportPinPlan` (zoom < 7 → counts; else pins of the ≤ 8 airports
  with echoes in view + 0.5° margin, nearest first), per-airport pin cache,
  counts fresh for 1 min, `MapEchoSocket` joins the shown airports' rooms
  and reloads one on `terminal_echo:changed`. Count bubbles feed the
  heatmap when zoomed out. Same-spot echoes: pins cluster up to zoom 19,
  and a bubble whose echoes share one point (or that only splits past
  zoom 18) opens `EchoStackSheet`. analyze clean, 190 tests, APK builds.
- Not on a device yet. Known gap: an airport with **no** echoes isn't
  watched, so its first echo shows after the next counts refresh
  (≤ 1 min, on the next camera move).

## Status at a glance

| Work | Code | Tests | On device |
|---|---|---|---|
| A. Map "not available" fix | Done | Pass | ✅ Verified on Xiaomi |
| B. Radar look on airport circles | Done | Pass | ✅ Realme grid; ⚠️ Xiaomi sweep shown but look not confirmed |
| C. Pins missing when zoomed out (API + app) | Done | Pass | ✅ Realme clusters; ⚠️ Pacific swap fix (D) not on device |
| D. Flipped Pacific bounds from Mapbox (new) | Done | Pass | ❌ Not on device yet |
| E. Hide features a phone can't render (radar) | Done | Pass | ✅ Realme |

Last full run (2026-10-02 afternoon): app `flutter analyze` clean,
`flutter test` **170** passed, `dart format` check clean;
API `tsc` clean, `vitest run` 193 passed (API unchanged today).

---

## Resume here: Monday 2026-10-05

**Checkpoint at end of 2026-10-02.** (Committed on 2026-10-05, see top.)

**What happened on 2026-10-02 afternoon:**
- Atlas blocked the PC (TLS `SSL alert number 80`); the user added the IP
  `49.151.112.108` under Atlas → Network Access. If the IP changes, add it
  again (the ping recipe is in the morning notes below).
- **User rule (applies to all features):** if a phone can't render a
  feature, it must not show at all. Done for the radar (E): its layers are
  added in their own try, and a failed update calls `_disableRadar` →
  plain circles, pins still load.
- **Realme** (lite): grid rings + spokes at Loakan ✅, NAIA pins ✅,
  zoomed-out Manila cluster that splits on tap ✅, no sweep (intended).
- **Xiaomi:** app ran, no crash, map requests all 200. The Pacific drag
  exposed a bug (D): on the globe Mapbox reports a view crossing the
  antimeridian with its edges **already wrapped and flipped** (e.g.
  sw = -122.1, ne = 114.4 for a view 44° tall), so the app asked for the
  other side of the world and Manila dropped out. Fix:
  `MapViewBounds.normalize(centerLng: …)` swaps the edges when the camera
  center isn't between them; `_refreshForViewport` passes
  `camera.center`. 4 new tests from the real values. The Xiaomi
  disconnected before the fixed build could be installed.

**Monday steps:**
1. Start the API **in its own window** (a background task gets killed at
   its time limit and leaves an orphaned `ts-node` on port 3001):
   `Start-Process cmd "/c npm run dev" -WorkingDirectory <gate-closes-api>`,
   then check `http://192.168.1.20:3001/health` and a login. If data calls
   fail with "Database not connected!", check the Atlas IP list.
2. Plug in the Xiaomi (`63ffc6dec2f4`), `flutter run -d 63ffc6dec2f4`.
3. **Pacific test (D):** zoom out to the globe, centre between Hawaii and
   Fiji, Manila at the left edge. Expect the Manila bubble to stay, and
   API map requests with `west > east` (e.g. `west=114 east=-122`), not
   200°+ wide ranges. Watch `GET /api/terminal-echo/map` in the API log.
4. **Sweep look (B):** ask the user whether the rotating arm's speed
   (4 s/turn) and brightness are OK; tune if not.
5. Then **commit when the user says so** (split below, now with D in the
   bounds commit), and move on to "Not started" items.

**Progress 2026-10-05 (morning):** API started in its own window (Atlas IP
unchanged, `49.151.112.108`; DB ping OK; login OK). Only the **realme** was
available, so steps 2–3 ran on it instead of the Xiaomi. First run failed
with `Network is unreachable`: the realme's **Wi-Fi was off** (turn it on,
SSID `FORHU EXT`). After that: Manila cluster shown, map requests all 200,
no crash. **Pacific test (D) still not done**: the phone hit low battery
and disconnected before reaching the globe view. Sweep look (B) still
needs the Xiaomi. New follow-up: the app's `GET /api/auth/me` returns
**404** (login and map unaffected); check which route the API exposes.

---

## Update 2026-10-02 (morning) — resume here after the PC restart

**Done today (all uncommitted):**
- Re-ran every check: app analyze clean + **166** tests pass; API tsc clean
  + **193** tests pass. Code review of A/B/C: no bugs found.
- Re-checked C against the live local API (logged in as ava.morgan):
  whole world **20** pins, across the date line **16**, Manila **12**.
- Fixed stale docs (counts, radar look, device status, dead links):
  app `HANDOFF.md` §4, `MAP_EXPO_PARITY.md`,
  `FLUTTER_V2_SYSTEM_ARCHITECTURE.md` §4.5/§5.3/§8; API
  `ARCHITECTURE_EVALUATION.md` (status note at the top: §1–8 are the original
  audit, mostly fixed; `MERGE_HARDENING_PLAN.md` was never committed);
  Expo `docs/SYSTEM_ARCHITECTURE_AND_FUNCTIONALITY_MATRIX.md` (v2
  Connections/messaging built; `WSL2_LOCAL_BUILD_SETUP.md` not in any repo).

**Was about to:** run the app on the Xiaomi and do "Must do" items 1–2
below (zoomed-out clusters over Manila, a view across the Pacific, radar at
Loakan). Steps after the restart:
1. Start the API: `cd gate-closes-api && npm run dev`, check
   `http://192.168.1.20:3001/health`.
2. Plug in the Xiaomi (USB debugging on, same Wi-Fi), check
   `& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices`.
3. `cd gate-closes-app-v2 && flutter run -d 63ffc6dec2f4`.

**Second restart (2026-10-02, ~12:40):** the device run was blocked before
any check. The API answered `/health` but every data call returned
"Database not connected!": Atlas refused TLS (`SSL alert number 80`), which
means this PC's public IP (`49.151.112.108` at the time) is not on the Atlas
Network Access list. Fix: add the current IP in Atlas, then start the API
(`rs` in nodemon if it's already running). Run only **one** `npm run dev`:
a second one crashes with `EADDRINUSE` on 3001. Quick DB check from
`gate-closes-api`: a `MongoClient` ping using `.env` (`mongoose` isn't a
dependency; use `mongodb`). The realme lost its USB connection mid-run; if
the map tab then shows "Map isn't available", tap *Try the map again*.

**Afternoon (2026-10-02):** Atlas IP allowed, API up, app running on the
realme. Realme shows the circle with no sweep (expected on lite maps).
New user rule: **a feature a phone can't render must not show at all.**
Audit of the map: whole map (render guard), terrain/3D and sweep (skipped
on lite), theme (try/catch) already comply. Fixed the two gaps in
`world_map_page.dart`: radar layers are added in their own try (failure →
plain circles, pins still load), and a failed grid/sweep update calls
`_disableRadar` (hides the radar for that map session instead of retrying
every frame). Analyze clean, 166 tests pass.

**Realme result (2026-10-02, with the change above):** user confirmed the
static radar grid (rings + spokes) at Loakan, pins at NAIA, and the
zoomed-out cluster over Manila that splits on tap. No sweep, as intended.
No crash; the USB link dropped once (app kept running, adb restart fixed
it). "Must do" 3 is done; 1 (sweep tuning) and the Pacific-view part of 2
still need the Xiaomi. Run the local API in its own window
(`Start-Process cmd "/c npm run dev"`): a background task gets killed at
its time limit and leaves an orphaned `ts-node` holding port 3001.

**Small follow-up found:** API `terminal.echo.repository.ts` has two doc
comments stacked above `findByAirportNameWithFile` (from `45d6768`); the
older one should move or merge. Cosmetic.

---

## A. "Map isn't available on this phone" (Xiaomi 2201116SG)

**Symptom:** map tab always showed the notice; no airport circles, no pins.

**Cause:** once the user is located, the pulsing location puck redraws
every frame, so Mapbox never fires `onMapIdle`. Both the render guard
(`MapRenderGuard`) and the viewport refresh (circles + pins) waited on idle,
so the 25 s timeout turned the map off. Diagnosed with temporary logging:
style loaded in 60 ms, `mapLoaded` after ~1 s, 490 frames, zero idle events.
Not Impeller (turning it off changed nothing; that change was reverted).

**Fix** (`lib/features/worldMap/presentation/pages/world_map_page.dart`):
- Guard settles on `onMapLoadedListener` + our layers added
  (`_onMapLoaded` → `_settleRenderIfReady`).
- Viewport refresh runs off a debounced `onCameraChangeListener`
  (`_scheduleViewportRefresh`).
- `docs/HANDOFF.md` §1 has a Xiaomi row.

**Verified on device:** map loads in ~1 s; the Loakan (BAG) 8 km circle
shows; pin requests fire; force-close + relaunch past 25 s stays up.

## B. Radar look inside the airport circles

User's choice: **grid + rotating sweep**, in the **app lime accent**
(`0xFFBBE40A`).

- `lib/features/worldMap/domain/entities/airport_radar.dart`:
  recovers each circle's center/radius from its polygon (`discs`), builds
  the grid (3 rings, 12 spokes, 72 edge ticks; one MultiLineString per
  kind per airport), the sweep wedge (8 fading slices, 48°), and
  `nearest()` (antimeridian-aware).
- `world_map_page.dart`: lime fill/glow/outline, `airport-radar-grid` and
  `airport-radar-sweep` layers; sweep timer at ~15 fps.
- **Payload limits** (an oversized GeoJSON once ran Android out of memory):
  radar only from zoom ≥ 10, grid on the 12 airports nearest the view
  center, sweep on the nearest 6. Grid max ≈ 82 KB per camera move,
  sweep ≈ 160 KB/s.
- Sweep is off on lite maps (32-bit ARM) and paused while the app is in
  the background (`AppLifecycleListener`).
- Tests: `test/features/worldMap/domain/airport_radar_test.dart`.

## C. Pins missing/stale when zoomed out (clusters)

**Cause (API):** `TerminalEchoRepo.findAllForMap` used `$geoWithin` with a
rectangle Polygon. Mongo reads a ring wider than 180° as the other side of
the globe: 190°-wide view → 4 pins instead of 16; whole world → 0. Views
crossing the antimeridian (west > east) were rejected with 400, so the app
fell back to stale cached pins.

**Fix:**
- API `gate-closes-api/src/repositories/terminal.echo.repository.ts`:
  new `mapBoundsMatch()`, a plain lng/lat range on `location.coordinates`;
  `$or` of two lng ranges when west > east; no lng filter for a
  full-world view.
- API `gate-closes-api/src/controllers/terminal.echo.controller.ts`: accepts
  west > east.
- API tests in `gate-closes-api/test/terminal.echo.map.features.spec.ts`.
- App `lib/features/worldMap/domain/entities/map_view_bounds.dart`: wraps
  Mapbox's unwrapped longitudes (e.g. east = 200) into -180..180, ≥ 360°
  becomes the whole world, latitude clamped; and (D, 2026-10-02) swaps
  edges back when the camera center isn't inside them (globe reports
  flipped edges across the antimeridian). Used in `_refreshForViewport`.
  Tests: `test/features/worldMap/domain/map_view_bounds_test.dart`.

**Verified:** against the real DB and the live local API (nodemon
reloaded): whole world → 20 pins, across date line → 16, Manila → 12.

---

## Not done yet (see "Resume here: Monday 2026-10-05" above first)

### Must do
1. **Radar look on the Xiaomi:** the sweep runs there; the user hasn't
   said yet whether speed (4 s per turn), opacity and min zoom (10) are
   right. Realme grid is confirmed.
2. **Pacific view on the Xiaomi with fix D installed.** Answered: on the
   globe Mapbox reports wrapped, flipped edges (not unwrapped ones); fix D
   handles it, not yet seen on device. Realme clusters confirmed.
3. ~~Re-test the realme~~: done 2026-10-02 (grid, pins, clusters, no crash).
4. **Commit** when the user says so. Suggested split:
   - app `fix(map): settle render guard on map load, not idle`
   - app `feat(map): radar grid and sweep on airport boundaries` (incl. E:
     radar hidden when it can't render)
   - app `fix(map): normalize view bounds across the antimeridian` (incl. D)
   - api `fix(echo): map pins for wide and antimeridian views`

   Caveat: `world_map_page.dart` holds all three app changes, so separate
   app commits need partial staging. The alternative is one app commit +
   one API commit.

### Not started
5. **Two-phone Baton Touch test.** Phone 1 (Xiaomi): `ava.morgan@example.com`
   with MNL → SIN. Phone 2: `liam.chen@example.com` with SIN → MNL.
   Password `Password123!`. Seeded users already have random tickets:
   Profile → flight card → **Delete Boarding Pass**, then **Add Boarding
   Pass** and pick the sample image. The second phone was never
   connected, and the SIN → MNL image is not on any phone yet.
6. **Scanner never run on the sample tickets.** Unknown whether the
   PDF417 barcode decodes in the app.

### Known limits / follow-ups (not bugs today)
- API map query returns at most the **100 newest** echoes in view; with
  real volume a world view shows only those.
- The new map query doesn't use the `location` 2dsphere index (scan).
  Fine at 20 echoes; add an index on the coordinate fields if echoes
  reach tens of thousands.
- `MapRenderGuard` can still false-trigger if the app is killed during the
  first 5 s of a map load (e.g. `flutter run` disconnect). "Try the map
  again" clears it.

---

## Handy facts

- Sample boarding passes (fake data, **never** put in
  `test/fixtures/tickets/`):
  `C:\Users\devrm\Pictures\sample-boarding-pass.png` (PR 501 MNL → SIN,
  also on the Xiaomi under Pictures) and
  `C:\Users\devrm\Pictures\sample-boarding-pass-SIN-MNL.png` (SQ 916).
- Matching rules (API `src/domain/conversation/strategies/`):
  Parallel Soul = same from + to; Destination Thread = same to, different
  from, arrivals within 24 h; Baton Touch = one's destination is the
  other's origin, not the same flight.
- Xiaomi device id `63ffc6dec2f4`. `adb` is not on PATH:
  `& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices`.
  Only one `flutter run` at a time; it replaces any installed build.
- Local API: `http://192.168.1.20:3001`.
- The phone is in Baguio; it resolves to Loakan (BAG, 8 km). Seeded
  echoes are around NAIA (Manila).
