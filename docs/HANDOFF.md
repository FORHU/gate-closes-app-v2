# Handoff — where we left off (2026-10-01)

Read this first to continue. Related docs in this folder:
`MAP_EXPO_PARITY.md` (map architecture, gaps, low-end phones),
`FLUTTER_V2_SYSTEM_ARCHITECTURE.md` (system + API contracts),
`BOARDING_PASS_INTELLIGENCE_PLAN.md` (frozen feature).

> **Start here (2026-10-07):** `SESSION_2026-10-06_OFFERS_RBAC.md`,
> section "Resume here (2026-10-07)". Pins, offers, roles, seeders and the
> airport cleanup are committed on feature branches (not merged); the
> per-airport radius admin is built but **uncommitted**. API on **3001**.
>
> **Map work from 2026-10-01/02 (map fixes, radar, zoomed-out pins,
> Pacific bounds) was committed locally on 2026-10-05, not pushed:**
> app `9871df9`, `93217c7`, `59bb98b`; API `0888f77`, `9c7040a`. Still to
> check on a phone: the Pacific view and the sweep look. Details and the
> next feature (load pins per airport) in `SESSION_2026-10-01_MAP_WORK.md`.

Last pushed: app `827f904`, API `945afed`. **Commit only when the user asks**: one conventional commit
per feature, **no Co-Authored-By / Claude attribution**, each commit tested
before it is made. Never commit ticket PII or ticket images.

## 1. Device testing on a low-end phone

Test phone: **realme RMX3231** (realme C11 2021), Android 11, 32-bit ARM,
PowerVR GPU. Device id `0151312S28102753`. Package
`com.reeethepuffer.gateclosesapp`.

| Symptom | Cause | Status |
| :--- | :--- | :--- |
| Dart error at `_onStyleLoaded` → no pins/boundaries | Badges sent to Mapbox as raw RGBA; the plugin decodes image **files** | **Fixed**: badges ship as PNGs (`assets/map_badges/*.png`, built by `tool/render_map_badges.dart`) |
| Native `SIGSEGV` in `libGLESv2_powervr.so`, thread `1.raster` | Flutter raster thread in the PowerVR driver | **Probably fixed**: no new crash entry on 2026-10-01 |
| App didn't open (Mapbox `BufPoolFreeBuffer` spam) | Map too heavy for the GPU/RAM | **Mitigated**: lite map on 32-bit ARM + render guard |
| "Map isn't available" on **Xiaomi 2201116SG** (Android 13), no boundaries/pins | Once the user is located the pulsing puck redraws every frame, so `onMapIdle` never fired; the guard and the viewport refresh both waited on it | **Fixed**: guard settles on `onMapLoaded` + layers added; viewport refresh runs off a debounced `onCameraChange`. Verified on device 2026-10-01 (not Impeller: opting out changed nothing) |
| Voice note upload 500 | Local API had no S3 credentials (provider chain only) | **Fixed** in API `3b86956` (restart the local API) |
| `Bad state: No element` in the voice composer | Preview player closed before playback ended | **Fixed** in app `827f904` |

**2026-10-01 run** (`flutter run -d 0151312S28102753 --no-enable-impeller`):
the app opened and stayed up; no new crash entry, no low-memory kill. The
`BufPoolFreeBuffer` lines are PowerVR driver noise, and Mapbox's
`ClassNotFoundException` lines at start-up are harmless. Only one
`flutter run` at a time: two builds writing `app-debug.apk` at once make
`aapt` fail with "Invalid file". Reattach with `flutter attach -d …`.

**Render guard** (`MapRenderGuard`): marker saved before the map starts,
cleared after it renders and stays up 5 s. If the app dies in between, or
the map doesn't render in 25 s (online), the map tab shows "Map isn't
available on this phone" with *Open Feed* / *Try the map again*. It can
false-trigger if the app is closed during that window; retry clears it.

### Next steps
1. Restart the local API, log in as a seeded user (section 3), then check:
   map pins/clusters at NAIA, pin card + START CONVERSATION, gate dialog on
   the center button, feed (12 NAIA echoes) and feed airport search,
   recording + posting a voice echo, Map Lighting, offline banner.
2. Run once **without** `--no-enable-impeller`. If it crashes on `1.raster`,
   disable Impeller in `android/app/src/main/AndroidManifest.xml`:
   `<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />`
3. If the lite map can't open: try mercator instead of globe, and drop the
   heatmap on lite phones.
4. Test on a newer phone/emulator for the full look (terrain, 3D buildings).

Connect phone: USB debugging on, accept the prompt; if `offline`:
`adb kill-server && adb start-server && adb devices`.

## 2. API deploy: moving from Coolify to SSM (AWS devs)

`ci-cd.yml` has two deploy jobs, switched by the **`AWS_DEPLOY_ROLE_ARN`**
repository variable:
* unset → `cd` posts the Coolify webhook (current production deploy);
* set → `cd-ssm`: GitHub OIDC → image to ECR → env file as a SecureString
  in Parameter Store → SSM Run Command on EC2; fails if `/health` doesn't
  answer. Modeled on fox-passport's staging deploy.

To do, in order: OIDC deploy role (ECR push, `ssm:PutParameter` /
`SendCommand` / `GetCommandInvocation`, KMS) · EC2 with SSM agent, Docker,
curl and an instance role (S3 bucket, ECR pull, `ssm:GetParameter` on
`/gate-closes/api-env`) · reverse proxy (container listens on
`127.0.0.1:3001`) · repo variables (`AWS_REGION`, `EC2_INSTANCE_ID`,
`ECR_REPOSITORY`, optional `DOCKER_PLATFORM=linux/arm64`, `SSM_ENV_PARAM`,
plus app settings) and secrets (`MONGO_URI`, `SECRET_KEY`,
`ACCESS_TOKEN_SECRET`, `REFRESH_TOKEN_SECRET`, `MAILER_PASSWORD`,
`REDIS_PASSWORD`) · **set `AWS_DEPLOY_ROLE_ARN` last**.

S3 (`src/utils/s3.ts`): static keys only when `AWS_ACCESS_KEY` and
`AWS_SECRET_ACCESS_KEY` are both set (local dev); otherwise no credentials,
so the instance role applies. Never pass a partial credentials object (the
SDK then skips the role). fox-passport's `s3.ts` always passes one, so its
staging S3 likely fails ("Resolved credential object is not valid") —
worth checking there.

⚠ **Pushing API `main` deploys to production.** Production needs
`NODE_ENV=production` (otherwise CORS allows any origin) and its own
database.

## 3. Local data

The local `.env` points at Atlas `cluster0.dws23pl`, database
`gate-closes` (nobody else uses it, per the user). It holds **seed data**
(reseeded 2026-10-01): 10 users, 20 echoes (12 around NAIA, 4 of them
minutes old), flight tickets and PS/DT/BT conversations between seeded
users. Log in as `ava.morgan@example.com` / `Password123!` (all local seed
users share it). Seeded voice notes point at fake S3 URLs and won't play.

Reseed: `SEED_CONFIRM_DB=gate-closes npm run seed` — the seed wipes users,
echoes and conversations, so it refuses without that confirmation.

## 4. Verification (last run 2026-10-02 afternoon: all green)

Counts include the uncommitted 2026-10-01 map work.

App: `flutter analyze` (clean) · `flutter test` (170 pass) ·
`dart format --output=none --set-exit-if-changed lib test tool` ·
feature-isolation script from `.github/workflows/flutter_ci.yml` ·
`flutter build apk --debug`.

API: `npx tsc --noEmit` · `npx eslint "src/**/*.ts"` (not `yarn lint`: it
has `--fix`) · `npx vitest run` (193 pass). Prettier `--check` fails on
~113 files from CRLF line endings — pre-existing, not in CI. Yarn isn't
installed on this PC; `npm install` rewrites `yarn.lock` (restore it).

## 5. Open flags

* App CI blocked by GitHub billing.
* Local API `.env` sets `ACCESS_TOKEN_EXPIRY` to 7 days (code default 15m);
  make sure production doesn't.
* iOS 15.5 minimum — decision pending.
* Boarding pass frozen until 20+ real-ticket fixtures (redacted).
* Local `master` is behind `main`.
* API `tsconfig.test.json` typecheck has old errors (not in CI).
* `lib/l10n/generated/*` show as modified: line endings only, left alone.
* Not portable (no data): "fading" pins (echoes don't expire), alias
  gender prefix (echo has no gender), reply counts on pins.
* Optional: the app could use the existence check's `conversationId`
  instead of searching its conversation list (works either way).
* Expo parity still missing: intro slides + animated splash, "FINALIZE
  ECHO?" confirm, password strength meter and resend countdown.
