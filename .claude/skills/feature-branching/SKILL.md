---
name: feature-branching
description: >-
  Branching and checkpoint procedure for Gate Closes repos (gate-closes-api-v2,
  gate-closes-app-v2, gate-closes-landing, and the retired gate-closes-api /
  gate-closes-app). Use before starting any feature, fix, refactor, perf or docs
  change, when picking a base branch, when work spans several repos, or when
  preparing a pull request into staging.
---

# Feature Branching and Checkpoints

Every change in Gate Closes happens on a dedicated task branch cut from the
latest `staging`, and reaches `staging` through a pull request. `main` is
production and only receives `staging` when the owner decides to deliver.
The repo's `AGENTS.md` is the authority; this is the step-by-step version.

## 1. When to Use

Use this procedure whenever you:
- start a new feature, enhancement or optimization
- fix a bug or regression
- begin a refactor, migration or other multi-step change

## 2. Core Rules

1. **Never develop on `main`, `master` or `staging`.**
2. **One task per branch:** never mix unrelated work.
3. **Branch before you edit:** create and check out the branch before changing any file.
4. **Same name across repos:** if the task touches more than one repo, use an identical branch name in each.
5. **Never commit, stash, discard or move existing changes on your own.**
6. **Ask before acting:** no commit unless the user asks for one, no push or PR unless asked, and never delete a branch.

## 3. Branch Names

| Prefix | Use | Example |
|---|---|---|
| `feat/` | new feature | `feat/offer-claim-limits` |
| `fix/` | bug fix | `fix/echo-playback-seek` |
| `perf/` | performance | `perf/map-pin-batching` |
| `refactor/` | restructuring | `refactor/airport-repository` |
| `docs/` | documentation | `docs/agent-workflow` |
| `test/` | tests only | `test/offer-claim-race` |
| `chore/` | tooling, CI, dependencies | `chore/bump-prisma` |

## 4. Procedure

### Step 1: Inspect the working tree (each affected repo)
```bash
git status
git branch --show-current
git diff --stat
```
If there are uncommitted changes, **stop**. Work out whose they are and ask
the user what to do. Do not commit or stash them yourself.

### Step 2: Sync and compare the integration branches
```bash
git fetch origin
git log --oneline origin/main..origin/staging   # waiting to be delivered
git log --oneline origin/staging..origin/main   # should be empty; if not, report it
```

### Step 3: Check the branch name is free
```bash
git branch -a --list "*<type>/<short-description>*"
```
If it exists, inspect its history and ask before reusing it. Never reset it.

### Step 4: Create the branch from the latest staging
```bash
git switch --no-track -c <type>/<short-description> origin/staging
```
`gate-closes-app` (the retired Expo app) has no `staging`. Branch from
`origin/main` there, and only for work the user explicitly asked for.

### Step 5 (risky or multi-step work only): baseline checkpoint
With a clean tree:
```bash
git tag checkpoint-<short-description>-baseline
```
Keep the tag local unless the user asks for it to be pushed.

### Step 6: Implement in small, verified steps
- Make focused edits and run the repo's verification checklist (in its `AGENTS.md`) as you go.
- Keep existing flows working: sign-in, seeding, maps, offers.

### Step 7: Finish
- Run the full verification checklist and write the completion report described in `AGENTS.md`.
- **Commit only when the user asks**, using a conventional message (`feat(scope): ...`).
- **Push and open a PR only when the user asks:**
  ```bash
  git push -u origin <type>/<short-description>
  gh pr create --base staging
  ```
- **Check deploy triggers before any merge:** some repos deploy on push to `main` (see `.github/workflows/`).
- **Never delete the branch afterwards** unless the user says so.
