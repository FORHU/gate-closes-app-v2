# Handoff — where we left off (2026-09-30)

Read this first to continue. Related docs in this folder:
`MAP_EXPO_PARITY.md` (map architecture, gaps, low-end phones),
`FLUTTER_V2_SYSTEM_ARCHITECTURE.md` (system + API contracts),
`BOARDING_PASS_INTELLIGENCE_PLAN.md` (frozen feature).

## 1. Right now: device testing on a low-end phone

Test phone: **realme RMX3231** (realme C11 2021), Android 11, 32-bit ARM,
PowerVR GPU. Device id `0151312S28102753`.

What happened and what's fixed:

| Symptom | Cause | Status |
| :--- | :--- | :--- |
| Dart error at `_onStyleLoaded` → no pins/boundaries | Badges sent to Mapbox as raw RGBA; the plugin decodes image **files** (BitmapFactory / UIImage) | **Fixed**: badges ship as PNGs (`assets/map_badges/*.png`, built by `tool/render_map_badges.dart`) |
| Native `SIGSEGV` in `libGLESv2_powervr.so`, thread `1.raster` | Flutter raster thread in the PowerVR driver (runtime SVG→GPU rasterization + Impeller) | **Probably fixed**: no crash entry on the `--no-enable-impeller` run; runtime rasterization removed |
| App didn't open (no crash entry; Mapbox render thread `BufPoolFreeBuffer` spam) | Map too heavy for the GPU/RAM | **Mitigated**: lite map on 32-bit ARM (no terrain, no 3D buildings) + render guard |

**Render guard** (`MapRenderGuard`): marker saved before the map starts,
cleared after it renders and stays up 5 s. If the app dies in between, or
it doesn't render in 25 s (online), the map tab shows "Map isn't available
on this phone" with *Open Feed* / *Try the map again*.

### Next steps (in order)
1. `flutter run -d 0151312S28102753 --no-enable-impeller`
   * Opens → lite mode works.
   * Crashes/closes → reopen: the "Map isn't available" notice should show
     and Feed should work. Collect: `adb logcat -b crash -d` and
     `adb logcat -d | findstr /i "lowmemorykiller lmkd gateclosesapp"`.
2. Run once **without** `--no-enable-impeller`. If it crashes on `1.raster`,
   disable Impeller permanently in `android/app/src/main/AndroidManifest.xml`:
   `<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />`
3. If the lite map still can't open: next candidates are globe projection
   (use mercator on lite) and the heatmap layer on lite phones.
4. Test on a newer phone/emulator for the full look (terrain, 3D buildings).
5. Device checklist for everything built this session: map pins/clusters,
   pin card + START CONVERSATION, gate dialog on the center button,
   "Outside Terminal Zone" alert on send, echo card reactions,
   boarding time/terminal after a scan, Map Lighting, offline banner.

Connect phone: USB debugging on, accept the prompt; if `offline`:
`adb kill-server && adb start-server && adb devices`.

## 2. Commits

**Commit only when the user asks**: one conventional commit per feature,
**no Co-Authored-By / Claude attribution**. Never commit ticket PII or
ticket images.

**App (`gate-closes-app-v2`)** — all committed on local `main`, **not
pushed** (2026-10-01). Each commit builds and passes its tests alone:
`6e6a8e7` feat(echo) echo card · `d0cdb40` feat(echo) feed airport search ·
`6c44b14` feat(connections) DM draft · `32bdb70` feat(boarding-pass)
boarding time + terminal · `c1da906` feat(map) Map Lighting ·
`80eaf97` feat(nav) bottom nav + gate dialog · `9d33e2a` feat(map)
map-first shell · `036789a` docs. Left uncommitted on purpose:
`lib/l10n/generated/*` (line endings only).

**API (`gate-closes-api`)** — still uncommitted; suggested commits:
* `fix(security)`: CORS open only when `NODE_ENV` is development/test
  (`config.ts`, `app.ts`).
* `fix(ci)`: CI env uses `ACCESS_TOKEN_SECRET` / `REFRESH_TOKEN_SECRET`.
* `feat(map)`: map features carry `createdAt`, `listenCount`,
  `reactionCount` (no senderId); unbounded query `$limit: 200`; test
  `terminal.echo.map.features.spec.ts`.
* `feat(conversations)`: existence check returns `conversationId`.
* `docs`: `ARCHITECTURE_EVALUATION.md` (repo root; `docs/` is gitignored),
  index comment path.

⚠ **Pushing API `main` deploys to production** (Coolify webhook in
`ci-cd.yml`). Deploy is needed for pins to show "new" / weighted heatmap.

## 3. Verification (last run: all green)

App: `flutter analyze` (clean) · `flutter test` (152 pass) ·
`dart format --output=none --set-exit-if-changed lib test tool` ·
feature-isolation script from `.github/workflows/flutter_ci.yml` ·
`flutter build apk --debug`.

API: `npx tsc --noEmit` · `npx vitest run` (182 pass) · CI-style mocha
without `.env` (182 pass). Prettier `--check` fails on ~113 files from
CRLF line endings — pre-existing, not in CI.

## 4. Open flags

* App CI blocked by GitHub billing.
* Local API `.env` sets `ACCESS_TOKEN_EXPIRY` to 7 days (code default 15m);
  make sure production doesn't.
* iOS 15.5 minimum — decision pending.
* Boarding pass frozen until 20+ real-ticket fixtures (redacted).
* Local `master` is behind `main`.
* API `tsconfig.test.json` typecheck has old errors (not in CI).
* Not portable (no data): "fading" pins (echoes don't expire), alias
  gender prefix (echo has no gender), reply counts on pins.
* Optional: app could use the existence check's `conversationId` instead
  of searching its conversation list (works either way).
