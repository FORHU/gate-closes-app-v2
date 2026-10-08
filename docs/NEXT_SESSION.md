# Next session — start here

> Written 2026-10-08 (end of day). Only open work is listed; everything
> done is in the session notes and `FLUTTER_V2_SYSTEM_ARCHITECTURE.md`.
> **When the user says "let's continue", start task 1 below.**

## State at stop

| Repo | Branch | Head | Status |
| :--- | :--- | :--- | :--- |
| gate-closes-app-v2 | `feat/design-3d-map` | `bf8d6c7` | pushed, not merged (17 commits over `main`) |
| gate-closes-api | `feat/airport-offers-and-access` | `5e484aa` | pushed, not merged; **pushing API `main` deploys production** |
| gate-closes-landing | `feat/landing-revamp` | `d46ec23` | pushed, not merged |

All working trees clean. 247 app tests pass, `flutter analyze` clean; API
247 tests pass under vitest.

Database (Atlas `gate-closes`, cluster0.dws23pl — shared dev DB): sample
offers at BAG/MNL (vouchers, gifts, ads; `npm run seed:base`, never
wipes), 5 test echoes on one NAIA spot whose text starts with
`[crowd-test]` (one-off insert; delete them when no longer needed).
`npm run seed` WIPES users/echoes/conversations — the test login is a
demo user; don't run it without asking.

## How to resume

1. API: `cd gate-closes-api && npm run dev` (port 3001, own window).
2. Phones on the PC's Wi-Fi (PC `192.168.1.20`). Xiaomi `63ffc6dec2f4`
   (3D map, turns Wi-Fi off by itself: `adb shell svc wifi enable`);
   realme `0151312S28102753` (lite map).
3. Build for testing: `flutter build apk --profile --dart-define-from-file=.env.dev`
   (debug builds are useless for performance). Install with
   `adb -s <id> install -r build/app/outputs/flutter-apk/app-profile.apk`;
   installing closes the app.
4. adb gestures: send `input motionevent DOWN/MOVE/UP` in ONE `adb shell`
   call (separate calls jam Mapbox's gestures until the app restarts).
   On the realme each `input` takes ~1.3 s: start the tap with `&`.

---

## Task 1 — System Discovery & Connection Audit (top priority)

Requested by the user (2026-10-08): the project was handed over without
proper documentation, so before new features: discover, trace, verify,
document, test, then improve. **No aggressive refactoring or removal in
this phase; nothing marked ❓ Unknown is removed or rewritten.**

### Deliverable
`gate-closes-app-v2/docs/GATE_CLOSES_SYSTEM_DOCUMENTATION.md` with:
1 What Gate Closes is · 2 Main user journey · 3 Feature inventory ·
4 Flutter architecture · 5 API architecture · 6 Database architecture ·
7 Socket.IO architecture · 8 External services · 9 Authentication ·
10 Feature → API mapping · 11 Feature → database mapping · 12 Known
issues · 13 Unknown/undocumented behavior · 14 Technical debt ·
15 Recommended improvements.

Every feature/endpoint/event/model gets: ✅ Confirmed · ⚠️ Partial ·
❌ Broken · ❓ Unknown.

### Steps (in this order)
1. **Inventory from the code, not the docs** (cheap, mechanical):
   - App: every route in `lib/routes/`, every page, controller and
     repository per feature; every `ApiEndpoints` constant; every socket
     `emit`/`on`.
   - API: every route file in `src/routes/` (15) with middleware/auth;
     controllers → services → repositories → collections; 19 models in
     `src/models/`; Redis keys (`RedisUtil`), socket events (~16 distinct
     names found with a grep); external clients (S3, Mapbox, mail, …).
   - Landing: its pages and the admin area, and which API calls each makes.
2. **Feature inventory**: for each feature — what it does, where it is
   accessed, data used, local vs server, realtime or not, which
   endpoint/event, status.
3. **Trace each major feature end to end**:
   Flutter UI → Riverpod → API/Socket → controller/service → MongoDB/Redis
   → response → UI. Read the real code at each hop.
4. **Socket.IO table**: event → who joins (room) → trigger → payload →
   receiver → UI behavior. Focus: Terminal Echo, airport rooms, map,
   conversations, notifications, legacy events.
5. **Database relationships**: User → FlightTicket → (flight fields) →
   Airport → map content (echoes, offers) → replies/reactions/claims.
   Find legacy models, unused fields, orphans, data the app never uses.
   Read-only queries only (`NODE_PATH=…/node_modules node script.cjs`).
6. **External services & environment**: Mapbox, ML Kit (on-device OCR),
   S3/CloudFront, Redis, Socket.IO, mail/OTP, MongoDB Atlas; every env var
   in API/app/landing; dev vs prod; what breaks when each is down.
7. **End-to-end journeys on the phones** (profile builds):
   - Login → capture ticket (barcode/OCR) → ticket saved → airport detected
     → map → radar → detect a record → open it → start a conversation.
   - Airport → radar → detect a voucher → open → claim → claimed state →
     claim again refused.
   Record what was actually seen vs only unit-tested.
8. Write the document; list unknowns explicitly.

### Evaluation of the plan (2026-10-08)
- Sound and needed: the existing docs are partial and some are wrong.
  Example already found: `docs/BACKEND_INTEGRATION.md` describes a
  template backend (Express + Prisma + PostgreSQL), not this API
  (Express + MongoDB + Redis + Socket.IO) → classify as legacy/❓.
- Reuse, don't redo: `FLUTTER_V2_SYSTEM_ARCHITECTURE.md` (app side, map,
  connections diagram §4.7, API contracts §5), API `CONTEXT.md` and
  `ARCHITECTURE_EVALUATION.md`, landing `CONTEXT.md` and `docs/adr/`, the
  session notes, `BRUTE_FORCE_TESTING_PLAN.md` (user's, device-checked).
  Verify each claim against code; mark it ✅/⚠️ rather than copy it.
- Scope is large (three repos). Do it in passes, saving the document
  after each step so a stop mid-way loses nothing: inventory first (an
  hour or two), then traces per feature.
- "User → Ticket → Flight → Airport": there is no separate Flight model
  in the app (the flight lives on the ticket) — confirm on the API side.
- Known issues to record from the start: the staff test password is in a
  public repo's seeder (`GateCloses123!`); Node's DEP0170 warning prints
  the Mongo URI with its password in the API logs; API `npm test` (mocha,
  Node 24) can't load ESM `kdbush` (vitest runs the suite); GitHub
  Actions blocked by billing; `WorldMapPage` is ~2,600 lines (target
  `WorldMapRenderer`, after the audit).

---

## Other open work (after the audit, or when the user asks)

- **Device checks**: an ad and the offer dots at zoom 16 (spots are random
  per traveler per day); the non-lime echo types (need a viewer whose
  flight ticket matches another traveler's — see the affinity rules in
  `FLUTTER_V2_SYSTEM_ARCHITECTURE.md` §4.7). 6 items still `[ ]` in
  `BRUTE_FORCE_TESTING_PLAN.md`.
- **Airport search by code or city** ("MNL", "Manila" find nothing): parked
  by the user; needs API work (no city field in the DB).
- **Places beyond airports** (stations, ports): raised 2026-10-06, not
  started.
- **Real airport outlines** from OpenStreetMap instead of circles (airport
  cleanup step 3): not started.
- **Pull requests / merge** of the three branches into `main`: when the user
  says so (API `main` deploys production).
- **iOS** build and device check (needs a Mac); 20+ real boarding-pass
  fixtures for the parser.
