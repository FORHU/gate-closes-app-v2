# Session 2026-10-06: map zoom tuning, offers, roles

## Resume here

**Committed on branches, not pushed, not merged** (2026-10-06):
- API `feat/airport-offers-and-access`: nodemon, echo map per airport,
  login 401 fix, roles/permissions, offers.
- App `feat/map-airport-pins-and-offers`: Impeller off, pins per airport
  + heat clouds, offers, these notes.
- Landing `feat/landing-revamp`: revamp, onboarding steps, admin area.

Pushing API `main` deploys production: merge/push only when the user
says so. Still temporary: API on **3101**, app `.env.dev` → 3101 (see
`SESSION_2026-10-05_AIRPORT_PINS.md`).

`git status` in `gate-closes-api` still lists ~100 files whose only
change is line endings (prettier, by mistake; `git diff` is empty for
them, none were committed). To clean (Git Bash, in `gate-closes-api`):
`for f in $(git status --short | awk '$1=="M"{print $2}'); do git diff --quiet -- "$f" && git checkout -- "$f"; done`

**Next:** make the first super admin (`npm run seed:roles --
--super-admin <email>`), create an active offer at BAG in `/admin`, then
device-test offers at Loakan from zoom 10.5.

## Power cut fallout (fixed)
- Router got a new public IP → Atlas refused (TLS alert 80) → API said
  "Database not connected!". User added the new public IP in Atlas
  Network Access. Happens after every power cut: re-add the new IP.
- The API connects to Mongo only at start: after fixing access, restart it
  (touching a file under `src` makes nodemon restart).

## App (`gate-closes-app-v2`)
- Pin heat glow (`echo-heatmap`) removed: heat only as airport clouds when
  zoomed out.
- Clouds below zoom **10.5**, pins + circles + radar grid from 10.5
  (`AirportBoundaryIndex.minZoom`; was 7). User tuned it on the Xiaomi:
  "8.0 must still be fog", then "10 must be heat map".
- Impeller off in `AndroidManifest.xml`: the realme crashed in the PowerVR
  driver (`1.raster`) when launched without `--no-enable-impeller`.
- Device-confirmed (Xiaomi): switch at 10.5 both ways; cloud tap flies to
  zoom 13. Airports with no echoes show no cloud (by design for now).
- Checks: analyze clean, 191 tests pass.

## API (`gate-closes-api`)
### Offers (ads, vouchers, any admin-defined kind)
- `offer` + `offer.event` collections; glossary in API `CONTEXT.md`.
- App: `GET /offers?airport=MNL` → `{card, pins}`; pins at a seeded random
  spot within 80% of the airport radius (same all day per user);
  card = weighted random. `POST /offers/:id/events`, `POST /offers/:id/claim`
  (409 when sold out / already claimed; reveals `reward`).
- Admin: `/admin/offers` CRUD + `/:id/stats`.

### Roles (dynamic RBAC)
- `role` collection (unique `name`); five system roles seeded by
  `npm run seed:roles` (not at startup; also run by `npm run seed`) when
  missing, never overwritten (`--reset` restores defaults,
  `--super-admin <email>`): `user` (= no field on the user),
  `user_premium`, `developer`, `admin`, `super_admin`. Verified seeded.
- Permissions fixed in code (`src/domain/access/permissions.ts`, with
  descriptions); `requirePermission(...)` on routes; role permissions via
  `RoleSvc.permissionsFor` (30 s cache, cleared on role edits).
- Rules: super admin always has everything; system roles can't be deleted;
  a role in use can't be deleted; nobody changes their own role; a deleted
  role falls back to `user`.
- Admin endpoints: `/admin/permissions`, `/admin/roles` (CRUD,
  `roles:manage`), `/admin/users` (`users:read`), `PATCH
  /admin/users/:id/role` (`users:role`). `/auth/me` returns `role` +
  `permissions`.
- `/airport/crawl` and `/boundary/sync` now need `airports:manage`.
- First super admin: `npm run seed:roles -- --super-admin <email>` (not run).
- Schema in code: `ROLE_JSON_SCHEMA` (role.model.ts), listed in
  `src/utils/database.schemas.ts`; `npm run db:schemas` applies it. Needs
  `MONGO_ADMIN_URI` in `.env` (Atlas user with dbAdmin): the API's user is
  refused `collMod`. Not applied yet.
- Checks: tsc + eslint clean, vitest 238 pass.

## Landing revamp + admin (`gate-closes-landing`, branch `feat/landing-revamp`)
- Copy rewritten for travelers ("Leave a record where you pass through.",
  "starting with airports"), "How it works" steps per feature, download
  buttons "Coming soon to Android", FAQ link removed, images to WebP,
  SEO (metadata, share image, robots, sitemap), route groups.
- `/admin` inside the landing, FAOS structure like marketPlace admin
  (`features/` auth, offers, users, roles; `shared/`; `npm run validate`).
  Cookie session via `/backend/*` rewrite (`API_URL`), single shared
  refresh. Run on port 3000 (in the API's ALLOWED_ORIGINS).
- API fix: unknown email on login was 500, now 401.

## Offers in the app
- worldMap owns `OfferMapRepository` (feature isolation), `MapOffer`.
- Zoomed in (pins mode, >= 10.5): offer pins (own layer, `badge-offer`)
  of the airports in view, loaded after echo pins, cached 10 min; one
  card = dismissible banner above the nav bar for the nearest airport
  (no airport sheet exists). Sheet: image, text, link (url_launcher),
  Claim when `claimable` (API now sends it). Views: once per offer per
  session; click on the link button.
- Offers are optional: load failure or layer failure hides them only.
- Checks: analyze clean, 209 tests, format, isolation OK, APK builds.
- Not device-tested: needs a super admin + an active offer at BAG.
