# Next session: start here

> Written 2026-10-12 (end of day turning back point). Replaces the 2026-10-09 version.

The work now is **gate-closes-api-v2**: the API rebuilt on PostgreSQL,
Prisma and Better Auth. Its own docs are the source of truth:

- `gate-closes-api-v2/docs/TRACKER.md`: build steps, every flagged issue (GC-##), what's open
- `gate-closes-api-v2/docs/DECISIONS.md`: the 17 settled decisions
- `gate-closes-api-v2/README.md`: local setup, seeds, scripts

---

## State at stop (2026-10-12)

| Repo | Branch | State |
|---|---|---|
| **gate-closes-api-v2** | `main` = `3b0d33e` | **Steps 0–6 completed, verified, and pushed to `origin/main`.** Working tree clean. |
| gate-closes-api (v1) | `main` = `650a0ae` | Pushed. Untouched since; stays live until the app switches. |
| gate-closes-app-v2 | `main` | Clean resumption point documented. |
| gate-closes-landing | `feat/landing-revamp` | **Not merged**: conflicts with 11 other commits on `main` (tracker GC-20). |

### Step 6 Status: Fully Finished & Verified
The other editor finished all work on Step 6:
- All 18 type errors and 17 file formatting issues have been resolved.
- All quality gates pass 100%:
  - `pnpm typecheck`: 0 errors
  - `pnpm lint`: 0 errors / 0 warnings
  - `pnpm format:check`: 100% compliant
  - `pnpm build`: clean compilation (`tsc -p tsconfig.build.json`)
  - `pnpm db:check`: no schema drift
  - `pnpm test:all`: **29/29 files passed, 229/229 tests passed (0 failures)**
- Commits pushed to remote `origin/main`:
  - `1b8469c`: `feat: Step 6 - tickets, conversations, offers, admin, and file storage`
  - `3b0d33e`: `docs: record step 6 commit 1b8469c, close GC-06 and GC-07`

---

## How to resume

```bash
cd gate-closes/gate-closes-api-v2
pnpm infra:up          # Postgres+PostGIS :5440, Redis :6390, MinIO :9200
pnpm db:deploy
pnpm dev               # http://localhost:3006 (v1 stays on 3005)
pnpm typecheck && pnpm lint && pnpm format:check && pnpm test:all && pnpm db:check
```

---

## Next work

1. ~~**Test-Airport Review items**~~: done 2026-10-13 (TRACKER GC-58/59/60), commit `1141c68`.
2. ~~**Step 7**~~: done 2026-10-13, commit `1d60cf7`. `fs.conversation*` and `sovereign.future.signal` were models only in v1, so their Step 1 tables are the whole port; added todo (unmounted) and the org namespace.
3. ~~**Step 8**~~: done 2026-10-13: app-v2 `18d67d1` on `feat/api-v2-client`, landing `5735ecc` on `feat/admin-api-v2` (cut from `feat/landing-revamp`, so GC-20 still applies). GC-09 (Google sign-in) left: needs a client id.
4. **Step 9**: Phone check on the realme, same checklist as 2026-10-09.

---

## Waiting on a decision

- **GC-20**: `landing-revamp` merge conflicts.
- **GC-21**: MinIO only on this PC (teammates need `docker save`/`load`, or switch to RustFS).
- **GC-22**: Which repo the Flutter-template README review was about.
- **GC-23**: v1 local Redis (`mapanytime-api-redis-1` vs dedicated).
