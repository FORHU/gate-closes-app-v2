# Agent Rules

## Branching: Continuous Staging and On-Demand Main Synchronization

> This section takes precedence over any other branch or pull-request-target instruction in this file.
> `main` is this repository's production branch.

The development workflow is continuous and is not restricted to a daily schedule, a single task, or a fixed number of tasks.

- Before beginning a new development cycle, inspect the relationship between `main` and `staging` and synchronize them when necessary.
- All task branches must originate from the latest `staging`.
- Completed tasks must be submitted through PRs targeting `staging`.
- Developers may continue starting and completing additional tasks for as long as needed.
- Do not synchronize `staging` into `main` automatically after each task, after a fixed time interval, or simply because the day has ended.
- Synchronize `staging` into `main` only when the team explicitly decides that the accumulated changes are ready for delivery.
- Before synchronization, validate the combined changes and complete all required reviews and checks.
- Never merge unfinished or known-broken changes into `main`.
- After synchronization, verify the resulting branch state before continuing.
- **When a task is done, ask the repository owner / team lead whether it is all good.** They decide whether it merges and when `staging` is synchronized; an agent's or author's own judgment is not approval.
- **Check deploy triggers before merging into `staging`:** some repos deploy on pushes to `staging` (see `.github/workflows/`). Merging is a deployment decision, not just a code review.
- **Project board:** move the item through the product's GitHub Project — Backlog → To-Do → In progress → Done.

**Workflow:** Establish baseline → Develop tasks → Merge completed tasks into staging → Continue working or synchronize to main when ready → Repeat.

`staging` is the continuous integration branch. `main` is updated on demand when the team chooses to deliver the accumulated changes.

```bash
# Start a task
git fetch origin
git log --oneline origin/main..origin/staging   # what staging has that main doesn't
git checkout staging && git pull
git checkout -b <type>/<short-description>      # feat/, fix/, docs/, test/, chore/ ...

# Finish a task: open a PR into staging (never into main)
gh pr create --base staging

# Deliver (only when the owner decides): one PR from staging into main
gh pr create --base main --head staging
```


---

## 1. Work Safety

### Inspect Before Editing
- Before changing anything, check `git status`, the current branch and `git diff`.
- Work out whether any uncommitted changes belong to the current task.
- Never discard, reset, clean, stash or commit existing work without explicit authorization.

### One Branch Per Task
- Before writing code or changing files, create or switch to a dedicated task branch. Never develop directly on `main`, `master` or `staging`.
- Branch names:
  - `feat/<short-description>`: new features
  - `fix/<short-description>`: bug fixes
  - `perf/<short-description>`: performance improvements
  - `refactor/<short-description>`: refactoring
  - `docs/<short-description>`: documentation
  - `test/<short-description>`: tests
  - `chore/<short-description>`: tooling, CI, dependencies
- Never mix unrelated work into one branch (no caching work in an auth branch).
- **Cross-repo consistency:** if a task spans `gate-closes-api-v2`, `gate-closes-app-v2` and `gate-closes-landing`, use the same branch name in each affected repo.
- The `feature-branching` skill (`.claude/skills/feature-branching/SKILL.md`) has the step-by-step procedure.

### Preserve Existing Work
- If the working tree has unrelated uncommitted changes, do not commit, stash or move them on your own.
- If existing changes overlap the task, or their ownership is unclear, stop and ask before editing.
- Before switching branches, check that uncommitted changes won't be carried into another task.

### Branch Creation and Checkpoints
- Check whether the branch already exists (`git branch -a`) before creating it. If it does, inspect its status and history before reusing it.
- Never reset or overwrite an existing branch to force-match a preferred starting point.
- For risky or multi-step changes, set a recoverable baseline while the tree is clean (a local `checkpoint-<task>-baseline` tag). Never commit unrelated changes to create one.

### Commits, Pushes and Pull Requests
- **Commit only when the user explicitly asks for a commit.** "Proceed", "ok" or "continue" are not commit requests.
- Use conventional commit messages (`feat(scope): ...`, `fix(scope): ...`), one commit per feature.
- Do not push, open a pull request, merge into a shared branch or deploy unless the user asks.
- **Never delete branches** (local or remote: `git branch -d`/`-D`, `git push --delete`), even after a merge, unless the user explicitly says so. Branches are kept for audit, rollback and recovery.
- Never commit `.env` files, credentials, tokens, private keys or real user data (boarding passes, tickets, emails).

---

## 2. Scope and Honesty

- **Stay in scope:** no unrelated refactors, formatting sweeps or behaviour changes.
- **Keep what works working:** never regress existing flows (sign-in, seeding, offers, maps).
- Keep comments, docs and error handling that are unrelated to the change.
- **Report honestly:** if a test, lint or check fails, report the exact failure. A passing build or typecheck is not proof the feature works.
- Never declare a task complete while required verification is failing or was not run. Keep what was implemented separate from what was only planned.

---

## 3. This Repo

The Gate Closes mobile app: Flutter, running against `gate-closes-api-v2`. Entry points are `lib/main_dev.dart` and `lib/main_prod.dart`. Features live under `lib/features/`, shared code under `lib/core/` and `lib/shared/`.

Read before working:
- `docs/NEXT_SESSION.md`: current state and next work (start here)
- `docs/GATE_CLOSES_SYSTEM_DOCUMENTATION.md`: how the whole system fits together
- `SYSTEM_ARCHITECTURE.md`, `DESIGN_SYSTEM_AND_INTEGRATION.md`, `THEMING.md`: architecture, design system, theming
- `docs/BACKEND_INTEGRATION.md`: API contract with `gate-closes-api-v2`

### CI
- `flutter_ci.yml` only runs on pushes and PRs to **`main`**. PRs into `staging` get no CI, so run the checklist below locally before asking for review.

---

## 4. App Rules

- **Auth:** sign-in goes through `gate-closes-api-v2`'s Better Auth endpoints. Don't add another auth path.
- **Performance claims:**
  - Measure on a **profile** build (`flutter run --profile`) on a real phone, with before/after numbers (`adb shell dumpsys gfxinfo`).
  - Debug-build numbers don't count.
- **Low-end phones:** if a phone can't render a feature, hide the feature entirely. The core map and airport pins must always load.
- **Boarding pass:** the boarding-pass feature is frozen until there are 20+ real-ticket test fixtures. Never commit real ticket images or ticket data (PII).
- Keep generated files (`flutter gen-l10n` output) in sync with `lib/l10n/` sources.

---

## 5. Verification Checklist

The same steps `flutter_ci.yml` runs:
1. `flutter pub get`
2. `flutter gen-l10n`
3. `dart format --output=none --set-exit-if-changed .`
4. `flutter analyze`
5. `flutter test`

For UI or performance changes, also check on a real device and say which one.

---

## Completion Report

Before ending a task, report:
- **Branch:** the branch used in each repo.
- **Changes:** what was implemented or fixed.
- **Files:** the important files created, changed or removed.
- **Database:** schema changes, migrations, seeds (or "none").
- **Security:** auth, permissions or data-integrity implications (or "none").
- **Verification:** each check from the checklist above, marked one of:
  - **Passed**
  - **Failed (changes):** caused by this task; must be fixed before completion
  - **Pre-existing failure:** unrelated, and already failing before the task
  - **Blocked:** could not run (missing env or service); say what is missing

  Never skip a check silently or report a blocked check as passed.
- **Remaining work:** known gaps, edge cases and follow-ups.
