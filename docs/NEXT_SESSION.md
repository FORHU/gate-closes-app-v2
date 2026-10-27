# Next session: start here

> Updated 2026-10-27 for whoever picks the project up next. Replaces the
> 2026-10-26 version.

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

## State on 2026-10-27

Work now goes task branch → PR into **`staging`**; `main` only receives
`staging` when the owner decides to deliver, through one `staging` → `main`
PR per repo (no automation). Pushing `main` runs **Deploy Dev** for api-v2
and landing: it deploys to the dev server; production AWS isn't set up yet.

| Repo | `staging` = `main` | State |
|---|---|---|
| gate-closes-api-v2 | `8648efc` | everything delivered and deployed (#16) |
| gate-closes-app-v2 | `a768c2d` | everything delivered (#17), incl. 2D default (#16, #18) |
| gate-closes-landing | `c84d66d` | everything delivered and deployed (#35) |

After a delivery PR, `main` has one merge commit `staging` lacks (no file
changes). Fast-forward `staging` to it (`git push origin origin/main:staging`)
so both read 0/0; done for all three on 2026-10-27.

Done on 2026-10-26 (details in TRACKER.md, "Changes after the rebuild"):
GC-65, GC-66, GC-67 fixed; PostGIS 3.6; the map shows only busy airports
(large, or with echoes or a live offer); admin Auto / Show / Hide per airport;
airports centred on their terminal (OpenStreetMap, admin can fix); 2D map by
default with 3D as an opt-in setting.

Done on 2026-10-27: **GC-68** applied on the shared dev database
(`gatecloses_dev`): 2,714 of 3,478 airports now sit on their OSM terminal.

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

**Check `DATABASE_URL` in api-v2's `.env` first.** If it points at the shared
dev server, `pnpm dev` and `pnpm test:integration` use that server (and
integration tests create and wipe `<db>_test` there, GC-69). For local work
run with `DATABASE_URL='postgresql://gate_closes:local-dev-only@localhost:5440/gate_closes?schema=public'`.

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
- **The map is 2D (lite) on every phone by default.** 3D is Settings →
  General → 3D map, from the next launch, and only on phones the device
  ladder allows.
- **An old login from another database shows the old airport list.** The app
  falls back to its saved copy when the first requests are refused ("Failed
  to get session" in the API log). Force-stop and reopen after logging in.
- **Driving the phone with `adb shell input` while its screen is asleep**
  freezes the app (ANR: "does not have a focused window") and Android
  restarts it. Wake it first (`adb shell input keyevent KEYCODE_WAKEUP`).
- The test realme (RMX3231, PowerVR GPU) gets the "lite" map. If a phone
  can't draw the map, the app shows "Map isn't available on this phone".
  That's the render guard doing its job (see GC-64).

---

## Next work (pick from the top)

All of these are in TRACKER.md ("Open: needs a fix").

1. **Phone checks not done yet** (realme): GC-67 (play an echo past ~70%,
   the 👂 count goes up at once), Settings → General → 3D map switch, tap an
   offer dot at BAG (offer sheet opens), airports centred on their terminal,
   and the admin Terminal / On map columns in a browser. For a local run,
   first apply terminals to the local database too:
   `pnpm airports:terminals -- --apply` with the localhost `DATABASE_URL`.
2. **GC-64**: not reproduced on 2026-10-26; keep an eye out on cold start +
   login.
3. **GC-09**: Google sign-in. Needs someone with GCP access to change the
   Android OAuth client's package to `com.reeethepuffer.gateclosesapp`, then
   test on a phone.
4. **Production**: the AWS/GitHub setup in api-v2 `infra/README.md` is still
   to do. Ask before touching AWS.
5. **CI gap**: app-v2's Flutter CI (incl. "Enforce Feature Isolation") only
   runs on PRs into `main`, so run the AGENTS.md checklist locally before a
   `staging` PR. Adding CI on `staging` PRs is an open option (ask first).

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
- Task branches come from the latest `staging`; PRs go into `staging`. A
  task across repos uses the same branch name in each.
- Don't delete git branches.
- Write anything new you learn into TRACKER.md (issues) or this file
  (how-to), so the next person doesn't have to rediscover it.
