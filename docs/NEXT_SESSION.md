# Next session — start here (Turning Point)

> Written 2026-10-09 (end of day).
> **When resuming, start from "How to resume" and "Next work" below.**

---

## State at stop

| Repo | Branch | Head / Status | Notes |
| :--- | :--- | :--- | :--- |
| **gate-closes-app-v2** | `feat/design-3d-map` | Working tree clean | `docs/GATE_CLOSES_SYSTEM_DOCUMENTATION.md` completed (all 15 sections done). `.env.dev` pointed to `http://192.168.1.20:3005/api`. |
| **gate-closes-api** | `fix/password-reset-verification` | 5 modified files, 1 new test file | Off `main` + `feat/airport-offers-and-access`. Fixes C1/C2 security issues + `AirportRepo.searchByName` regex fix. Runs on **port 3005** (`PORT=3005` in `.env`). |
| **gate-closes-landing** | `feat/landing-revamp` | `d46ec23` | Clean. |

- **Port Isolation**: `gate-closes-api` is configured to use **port 3005**. Port `3001` remains dedicated to `ilovelawyer-api` and must not be touched or killed.
- **Physical Device**: realme RMX3263 (`0151312S28102753`, IP `192.168.1.64`), profile build installed and tested against port 3005.

---

## What was completed today (2026-10-09)

1. **Security Vulnerability Fixes (C1 & C2)**:
   - Added code verification window (`RESET_WINDOW_MS = 10 min`) and code consumption upon password reset.
   - Enforced `signupStep` checks in `POST /auth/set-username-gender` to prevent unauthorized profile mutations.
   - Created `test/password.reset.spec.ts` with 8 comprehensive unit tests (all 8 pass).
2. **Port Conflict Resolution**:
   - Reconfigured `gate-closes-api` to port **3005** (`PORT=3005` in `.env`).
   - Updated `gate-closes-app-v2/.env.dev` to `BASE_URL=http://192.168.1.20:3005/api`.
   - Setup `adb reverse tcp:3005 tcp:3005`.
3. **Repository Bug Fix**:
   - Fixed `AirportRepo.searchByName` in `airport.repository.ts` to match `$or: [{ airport: rx }, { iata: rx }, { icao: rx }]` and removed duplicate function definition. Code search ("BAG") now works correctly.
4. **Physical Device Verification (Step 7 of Audit)**:
   - Built profile APK (`flutter build apk --profile --dart-define-from-file=.env.dev`) and installed on realme.
   - Verified live device communication with port 3005 (HTTP & WebSockets return 200 OK).
   - Verified "Outside Airport" geofence barrier dialog.
   - Verified Loakan Airport ("BAG") search result and selection.
   - Verified Terminal Echo feed rendering live from Atlas MongoDB.
   - Verified Mapbox rendering: concentric radar range rings, crosshair bearing lines, and lime-green echo beacons.
   - Verified Offer pin placement (`Free coffee at Loakan`), reward code (`GATE-BAG-COFFEE`), and duplicate claim refusal (409 Conflict).
5. **System Audit Documentation (Step 8 of Audit)**:
   - Completed all 15 sections in `docs/GATE_CLOSES_SYSTEM_DOCUMENTATION.md`:
     - §1 What Gate Closes is
     - §2 Main user journey & Mermaid flow
     - §7.3 Device verification results
     - §14 Technical debt catalog
     - §15 Prioritized recommendations roadmap

---

## How to resume

1. **Start the API (Port 3005)**:
   ```bash
   cd c:\Users\devrm\Documents\GitHub\gate-closes\gate-closes-api
   npm run dev
   ```
   *(Ensure Redis is running locally on port 6379; port 3005 will attach automatically)*.

2. **Connect Device via adb Reverse**:
   ```bash
   adb -s 0151312S28102753 reverse tcp:3005 tcp:3005
   ```

3. **Run API Unit Tests**:
   ```bash
   cd c:\Users\devrm\Documents\GitHub\gate-closes\gate-closes-api
   npx vitest run test/password.reset.spec.ts
   ```

---

## Next work (when resuming)

1. **Git Commit & Clean**:
   - Commit the security and repository fixes on API branch `fix/password-reset-verification`:
     - `src/models/verification.code.model.ts`
     - `src/repositories/verification.code.repository.ts`
     - `src/repositories/airport.repository.ts`
     - `src/services/user.service.ts`
     - `src/services/user.auth.service.ts`
     - `test/password.reset.spec.ts`
   - Commit `docs/GATE_CLOSES_SYSTEM_DOCUMENTATION.md` and `docs/NEXT_SESSION.md` on `gate-closes-app-v2`.
2. **Execute High-Priority Improvements (§15 Roadmap)**:
   - **Fix Realtime Feed Sync**: Modify `terminal.echo.service.ts` to broadcast the fully serialized `TerminalEchoEntity` instead of the raw MongoDB `InsertOneResult` on `terminal_echo:changed`.
   - **Cursor Pagination**: Add `limit` and cursor parameters to `GET /terminal-echo`.
   - **Map Refactor**: Begin modularizing `world_map_page.dart` (2,968 lines) into discrete layers.
