# Next session: start here

> Written 2026-10-26 for whoever picks the project up next. Replaces the
> 2026-10-14 version.

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

## State on 2026-10-26

Work now goes task branch → PR into **`staging`**; `main` is production and
only receives `staging` when the owner decides to deliver (pushing `main`
deploys api-v2 and landing).

| Repo | `staging` | `main` | State |
|---|---|---|---|
| gate-closes-api-v2 | `72a7164` | `eb680ca` | `staging` is 7 PRs ahead of `main`: none of the 2026-10-26 work is deployed |
| gate-closes-app-v2 | `b1bebc4` | `f5796a9` | `staging` 4 PRs ahead. The 2D-default change is on `feat/map-2d-default`, not merged yet |
| gate-closes-landing | `685c2f5` | `d3589f0` | `staging` 4 PRs ahead |

Done on 2026-10-26 (details in TRACKER.md, "Changes after the rebuild"):
GC-65, GC-66, GC-67 fixed; PostGIS 3.6; the map shows only busy airports
(large, or with echoes or a live offer); admin Auto / Show / Hide per airport;
airports centred on their terminal (OpenStreetMap, admin can fix); 2D map by
default with 3D as an opt-in setting.

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

1. **Merge the 2D default** (app-v2 `feat/map-2d-default`) once the owner
   approves it, then check the Settings → 3D map switch on a phone.
2. **Phone checks not done yet**: GC-67 (play an echo past ~70%, the 👂 count
   goes up at once), tap an offer dot at BAG (offer sheet opens), and the
   admin Terminal / On map columns in a browser.
3. **GC-68**: once `staging` is on the dev server, run
   `pnpm airports:terminals` (dry run), then `-- --apply`. It changes shared
   data: ask the owner first.
4. **GC-64**: not reproduced on 2026-10-26; keep an eye out on cold start +
   login.
5. **GC-09**: Google sign-in. Needs someone with GCP access to change the
   Android OAuth client's package to `com.reeethepuffer.gateclosesapp`, then
   test on a phone.
6. **Production**: the AWS/GitHub setup in api-v2 `infra/README.md` is still
   to do. Ask before touching AWS.

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
