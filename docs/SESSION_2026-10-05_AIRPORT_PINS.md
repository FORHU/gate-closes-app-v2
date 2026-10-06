# Session 2026-10-05: per-airport pins, heat clouds

Pick-up notes for the next session. Read `HANDOFF.md` for the wider project
state; `SESSION_2026-10-01_MAP_WORK.md` has the earlier map work (radar,
render guard, antimeridian), now committed.

> Superseded: resume from `SESSION_2026-10-06_OFFERS_RBAC.md`. This work
> was committed on 2026-10-06 (app `ec91468`, API `2e400b9`); the open
> questions below were answered (pins/circles from zoom 10.5, heat only
> when zoomed out).

## Resume here: 2026-10-06

> ⚠️ **Port is temporarily changed: put it back when testing is done.**
> API runs on **3101** (not 3001) and the app's `.env.dev` points to 3101.
> When the user says testing is finished: start the API normally
> (`npm run dev`, port 3001 from `.env`), set `.env.dev` back to
> `BASE_URL=http://192.168.1.20:3001/api`, rebuild the app. Details in
> "Temporary setup to undo" below. Never commit the port change (`.env`
> is untouched; `.env.dev` is gitignored).

**Stopped at:** device-testing the zoom levels on the realme. The user was
at zoom 8.5 over Baguio and asked "can the pins and the radius still
there". **First thing tomorrow: ask what they meant**:
- (a) are pins + airport circle showing at 8.5? (they should: pins and
  circles from zoom 7), or
- (b) should pins + circles **also stay visible below zoom 7**, together
  with the heat cloud?

Also still unanswered: keep the pin heatmap glow **under the pins** when
zoomed in (current, Expo parity), or show heat only when zoomed out?
Recommended: heat only when zoomed out.

**Nothing from today's feature is committed** (both repos, all on `main`).
Commit only when the user says so. Suggested split:
- API: `feat(echo): map pins per airport and counts; refuse echoes outside airports`
- API: `chore(dev): nodemon watches src`
- App: `feat(map): load pins per airport with heat clouds and live updates`

Before committing the app: **remove or keep the debug zoom log?** (see
"Temporary" below). It is `kDebugMode`-only, so harmless in release.

## Temporary setup to undo (user will "put it back later")

| What | Now | Normal |
|---|---|---|
| API port | runs in its own cmd window with `set PORT=3101&& npm run dev` | `npm run dev` (`.env` has `PORT=3001`, untouched) |
| App `.env.dev` (gitignored) | `BASE_URL=http://192.168.1.20:3101/api` | `...:3001/api` |

Why: another project on this PC uses 3001 and 3002. After switching back,
rebuild the app. If `.env.dev` is edited from PowerShell 5.1, strip the
UTF-8 BOM it adds (`sed -i '1s/^\xEF\xBB\xBF//' .env.dev`).

## What was built today

### API (`gate-closes-api`, uncommitted)
- `GET /terminal-echo/map?airport=MNL`: one airport's pins, newest first,
  max 100 (index `idx_airportIata_createdAt`). `airport` + bounds → 400.
- `GET /terminal-echo/map/counts`: GeoJSON point per airport with echoes,
  at the airport's location (`$lookup` on `airport.iata`), properties
  `airportIata`, `airportName`, `count`, `latestAt`.
- `POST /terminal-echo` answers **422** "Echoes can only be posted inside
  an airport." when outside every radius (`EchoOutsideAirportError`). The
  service used to compute `insideRadius` and save anyway.
- `npm run dev` watches `src` (`--watch *.ts` never reloaded on Windows).
- Checks: tsc + eslint clean, vitest **205** pass (new
  `test/terminal.echo.airport.map.spec.ts`). Verified live: counts = 7
  airports, `?airport=mnl` = 12 pins.

### App (`gate-closes-app-v2`, uncommitted)
| Zoom | Shows |
|---|---|
| < 7 | **heat clouds only**, one per airport, bigger/hotter with more echoes (`heatWeight`, `cloudScale`, log-scaled). Tap a cloud → flies to zoom 13. Full phones: faint pulsing radar ring over each cloud; lite phones (realme): none. |
| ≥ 7 | pins of the ≤ 8 airports with echoes in view (+0.5° margin, nearest first), airport circles; pin heatmap glow under pins |
| ≥ 10 | radar grid on circles (sweep on full phones) |

- `AirportPinPlan` (`domain/entities/airport_pin_plan.dart`):
  `pinsMinZoom = AirportBoundaryIndex.minZoom` (7). Was 6 earlier today;
  user asked for heat at zoom 6.
- Per-airport pin cache; counts fresh 1 min; in-flight requests shared
  (camera fires several changes while settling).
- `MapEchoSocket` (`data/datasources/map_echo_socket.dart`): one socket,
  joins `airport:<IATA>` rooms of the shown airports, reloads one on
  `terminal_echo:changed`.
- Same-spot echoes (coords rounded to ~110 m): pins cluster up to zoom 19;
  a bubble whose echoes share one point (or splits only past 18) opens
  `EchoStackSheet` (list → pin card). Not device-tested: needs 2 echoes
  from one spot.
- Marker sizes by zoom (`_kPinSizes`, `_kBubbleSizes` in
  `world_map_page.dart`): small zoomed out, grow from ~12, cap 0.72 at 16.
- Heat cloud layer `airport-cloud` is separate from the Expo pin heatmap
  (`echo-heatmap`, back to Expo's values). Invisible `airport-cloud-tap`
  circle layer takes cloud taps.
- **Temporary:** `Map view: zoom … at lat, lng` debug log in
  `_refreshForViewport` (`kDebugMode` only), used to read the user's zoom.
- Checks: analyze clean, **191** tests pass, format clean, isolation OK,
  debug APK builds.

## Device results today (realme RMX3231, lite map)
- ✅ Loakan pin shows; only BAG loaded at start. Only one counts + one BAG
  request at start (after the in-flight fix).
- ✅ Zoomed out switches mode (no pins); clouds visible after giving them
  their own layer (first version was too faint: one point per airport).
- ✅ Zoom 6 shows heat (after moving the switch to 7).
- ⏳ Not yet confirmed: cloud tap flies into NAIA; cloud sizes Manila vs
  Baguio "different enough"; marker sizes at street level.
- Realme Wi-Fi was off at first (`Network is unreachable`): SSID `FORHU EXT`.

## Still open (not today's feature)
- Pacific/globe test of the antimeridian fix (less important now: zoomed
  out uses counts, not bounds).
- Radar sweep look: Xiaomi only (`63ffc6dec2f4`).
- Two-phone Baton Touch test: works from Baguio (phone ~4.6 km from
  Loakan, radius 8 km), BT depends on tickets, not echo location.
- `GET /api/auth/me` returns 404 (login and map unaffected).
- Known gap: an airport with **zero** echoes isn't watched; its first
  echo shows on the next counts refresh (≤ 1 min, next camera move).
- Expo app is being retired: no Expo compatibility work needed.

## How to run (tomorrow)
1. API in its own window: `Start-Process cmd "/k set PORT=3101&& npm run dev" -WorkingDirectory <gate-closes-api>`
   (or 3001 if switched back). Check `http://192.168.1.20:3101/health`.
2. Phone: `adb devices` (`& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices`),
   Wi-Fi on, then `flutter run -d 0151312S28102753 --no-enable-impeller`.
3. Read zoom from the run log: lines `Map view: zoom …`.
