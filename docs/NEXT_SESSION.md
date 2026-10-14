# Next session: start here

> Written 2026-10-14 for whoever picks the project up next. Replaces the
> 2026-10-12 version.

Gate Closes is a Flutter app (**gate-closes-app-v2**) on an Express +
PostgreSQL API (**gate-closes-api-v2**), with an admin panel in
**gate-closes-landing**. The v1 API (`gate-closes-api`, MongoDB) and the Expo
app (`gate-closes-app`) are retired: don't build on them.

Read these, in this order:

1. `gate-closes-api-v2/README.md`: local setup, seeds, scripts
2. `gate-closes-api-v2/docs/TRACKER.md`: build steps and every issue (GC-##); **open work lives here**
3. `gate-closes-api-v2/docs/DECISIONS.md`: the 17 settled decisions (don't reopen them without asking)
4. `gate-closes-app-v2/docs/GATE_CLOSES_SYSTEM_DOCUMENTATION.md`: how the whole system fits together

---

## State on 2026-10-14

| Repo | Branch | Head | State |
|---|---|---|---|
| gate-closes-api-v2 | `main` | `28e4903` | Steps 0–9 done. Pushed. |
| gate-closes-app-v2 | `main` | `5ed23ad` | Runs against api-v2. Pushed. |
| gate-closes-landing | `main` | `c0d21c0` | Admin uses api-v2; `landing-revamp` merged. Pushed. |

Step 9 (phone check on the realme) passed on 2026-10-14: login, airport
search, feed, radar, echo pin + voice playback, geofence, offer claim and
duplicate-claim. It found GC-64 to GC-67 (below).

---

## Run it locally

```bash
cd gate-closes-api-v2
pnpm install
pnpm infra:up          # Docker: Postgres+PostGIS :5440, Redis :6390, MinIO :9200
pnpm db:deploy
SEED_CONFIRM_DB=gate_closes pnpm seed   # first time only: demo data (wipes users)
pnpm dev               # http://localhost:3006/api
```

```bash
cd gate-closes-app-v2
flutter pub get
flutter run --dart-define-from-file=.env.dev
```

Demo login: `ava.morgan@example.com` / `Password123!`. Staff accounts
(`admin@example.com` etc., password `GateCloses123!`) are listed in the api-v2
README.

Before every commit in api-v2:
`pnpm typecheck && pnpm lint && pnpm format:check && pnpm test:all && pnpm db:check`

---

## Testing on a real Android phone

```bash
adb reverse tcp:3006 tcp:3006   # the API
adb reverse tcp:9200 tcp:9200   # MinIO: voice notes won't play without it
flutter build apk --profile --dart-define-from-file=.env.dev
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

Things that will confuse you if you don't know them:

- **A loose USB cable wipes `adb reverse`.** Symptoms: "No airports found",
  empty feed, spinners. Run `adb reverse --list`; if it's empty, re-run the two
  lines above.
- **Pins only become tappable when zoomed in.** Tap the "N ECHOES HERE · ZOOM
  IN" chip first. Offer pins are deliberately faint and need even more zoom.
- **The phone must be inside an airport to post an echo.** Away from one you
  get "Outside Airport". That's correct. Staff can fake a location under
  Profile → Developer (dev builds only).
- **Judge performance on profile builds**, never debug builds.
- The test realme (RMX3231, PowerVR GPU) gets the "lite" map. If a phone
  can't draw the map, the app shows "Map isn't available on this phone".
  That's the render guard doing its job (see GC-64).

---

## Next work (pick from the top)

All of these are in TRACKER.md, under "Open: needs a fix".

1. **GC-65**: offers at an airport with no echoes never appear on the map
   (`AirportPinPlan.forView` in app-v2 only plans airports with echoes). Easy
   to see at BAG.
2. **GC-66**: airport search "BAG" lists Wabag before Loakan; exact IATA/ICAO
   code matches should come first (api-v2 `AirportRepo.searchByName`).
3. **GC-67**: the echo card's listen count doesn't go up after playing.
4. **GC-64**: the map crashed once on first open after login on the realme.
   Try to reproduce it before changing anything.
5. **GC-09**: Google sign-in. Needs someone with GCP access to change the
   Android OAuth client's package to `com.reeethepuffer.gateclosesapp`, then
   test on a phone.
6. **Production**: Dockerfile, CI and a manual Deploy workflow are on api-v2
   `main`; the AWS/GitHub setup in api-v2 `infra/README.md` is still to do.
   Ask before touching AWS.

Still waiting on a decision (ask, don't guess): **GC-22** (which repo the
Flutter template review was about), **GC-23** (v1 local Redis).

---

## House rules

- **Commits**: one conventional commit per feature (`feat(map): …`,
  `fix(auth): …`), each tested before it's made. No AI/Claude attribution
  lines.
- **Never commit real boarding-pass/ticket images or passenger data.** The
  boarding-pass feature is frozen until there are 20+ real test tickets.
- **Don't change the landing/admin look** (colors, themes, layout) unless
  asked. It's Jahzel's design.
- **If a phone can't render a feature, hide it entirely**, but the core map
  and pins must still load.
- Don't delete git branches.
- Write anything new you learn into TRACKER.md (issues) or this file
  (how-to), so the next person doesn't have to rediscover it.
