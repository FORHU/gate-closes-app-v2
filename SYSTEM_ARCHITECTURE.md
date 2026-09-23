# Flutter Template — System Architecture

This document describes the **actual, verified** architecture of `flutter_template_v1` as of 2026-09-03 — what is really implemented and CI-enforced, versus what is scaffolded/aspirational. It sits alongside `README.md` (which states the *rules*) and documents the *reality* per feature, the way `SYSTEM_ARCHITECTURE.md` does for the JS/TS templates in this repo.

Reference implementation used for comparison: `mapanytime-market-app` (external, `C:\Users\My PC\Documents\Github\forhu\mapanytime\mapanytime-market-app`), a production app built on the same pattern with 13 fully-built features.

---

## Stack

| Concern | Library | Version |
|---|---|---|
| State management | `flutter_riverpod` | ^3.3.2 |
| Routing | `go_router` | ^17.3.0 |
| Networking | `dio` + `dio_smart_retry` | ^5.7.0 |
| Error modeling | `fpdart` (`Either<Failure, T>`) | ^1.2.0 |
| Secure storage | `flutter_secure_storage` | ^10.3.1 |
| Env config | `flutter_dotenv` | ^6.0.1 |
| Lint | `very_good_analysis` | dev |
| Test mocking | `mocktail` | dev |

---

## Layer pattern

```
lib/features/<feature>/
├── data/
│   ├── datasources/     # Dio-backed remote datasources
│   ├── models/          # DTOs (manual fromJson/toJson)
│   └── repositories/    # implements domain interface, catches AppException -> Failure
├── domain/
│   ├── entities/         # pure Dart
│   └── usecases/          # single-method classes calling repository
└── presentation/
    ├── controllers/       # Riverpod Notifier
    ├── pages/              # screens
    └── widgets/            # feature-local UI
```

Request flow: `UI → Controller → UseCase → Repository → Datasource → ApiService (Dio)`. Repositories catch typed `AppException`s and return `Either<Failure, T>` (fpdart); controllers `.fold()` the result — no `try/catch` in the presentation layer.

## Core/infra (`lib/core/`)

- `config/` — `AppConfig`/`Environment`, backed by `.env.dev` / `.env.prod` (both present with real, differentiated values — `BASE_URL`, `ENABLE_LOGGING`, `USE_MOCK`)
- `errors/failure.dart` + `errors/exceptions.dart` — sealed `Failure` (`ServerFailure`/`CacheFailure`/`NetworkFailure`/`UnauthorizedFailure`) and sealed `AppException`
- `services/api_service.dart` — Dio wrapper, typed exceptions on failure
- `services/interceptors/auth_interceptor.dart` — `QueuedInterceptor`; attaches bearer token, refreshes once on 401 via a separate bare Dio instance, queues concurrent requests during refresh, clears session and calls `onUnauthenticated` on failure
- `services/interceptors/mock_interceptor.dart` — serves canned responses when `USE_MOCK=true`, so `flutter run` works with zero backend
- `services/storage_service.dart` — secure-storage wrapper

## App shell

- `main_dev.dart` / `main_prod.dart` — thin entrypoints passing `AppConfig.dev()` / `AppConfig.prod()` into a shared `bootstrap()`
- `routes/` — `app_routes.dart` (go_router) + `route_names.dart`
- `theme/` — token-based (`colors`, `spacing`, `radius`, `typography`, `effects`), light/dark themes, component themes (button/card/input)
- `shared/widgets/` — design-system components (`AppInput`, `AppButton`, `AppCard`, etc.)
- `l10n/` — en/es ARB + generated localizations

## CI enforcement (`.github/workflows/flutter_ci.yml`)

Actually gates, on every push/PR:
1. `flutter gen-l10n`
2. `dart format --set-exit-if-changed`
3. `flutter analyze`
4. **Feature-isolation guard** — a grep-based script that fails the build if any `lib/features/*/` directory imports another feature, except the shared `auth` feature. This is real and enforced, unlike the equivalent claim in the `mapanytime-market-app` README (verified: that repo's CI has no such step, and 9 of its 13 features cross-import in practice).
5. `flutter test`

---

## Feature maturity matrix

All four features now follow the full layer pattern. `worldMap` is intentionally architecture-only per a scoping decision made 2026-09-03 — it has real data/domain/presentation layers but the page renders a list, not an actual map (no map SDK dependency added yet).

| Feature | data/ | domain/ | presentation/ | Tests | Status |
|---|---|---|---|---|---|
| `auth` | ✅ datasource, model, repository | ✅ entity, 3 usecases | ✅ controller, pages, widgets | ✅ repository, controller, api_service | **Fully built** — reference implementation for the pattern |
| `home` | ✅ `HomeRemoteDataSource` (`GET /users`), `HomeItemModel` | ✅ `HomeItem` entity, `GetHomeItemsUseCase` | ✅ `HomeController` (loading/items/error state), `HomePage` (welcome card + list, pull-to-refresh) | ✅ repository, controller, page (render + error state) | **Fully built** |
| `profile` | ✅ `ProfileRemoteDataSource` (`GET /users/me`), `ProfileModel` | ✅ `ProfileEntity` (adds bio/joinedAt), `GetProfileUseCase` | ✅ `ProfileController`, `ProfilePage` (falls back to session name/email while loading/on error) | ✅ repository, controller, page (render + error state) | **Fully built** |
| `worldMap` | ✅ `StoreRemoteDataSource` (`GET /stores/nearby`), `StoreModel` | ✅ `StoreEntity`, `GetNearbyStoresUseCase` | ✅ `WorldMapController` (typo fixed: `presentation/controllers/`), `WorldMapPage` (list view — **not a map yet**) | ✅ repository, controller, page (render + empty + error state) | **Architecture-built, map SDK deferred** |

`worldMap`'s domain/data layers are SDK-agnostic by design — swapping in `flutter_map`/`mapbox_maps_flutter` later only touches `WorldMapPage`'s rendering, not `WorldMapController`/`StoreRepository`.

---

## What changed in the 2026-09-03 pass

- Fixed the `presentation/contollers` → `presentation/controllers` typo in `worldMap` and removed the empty, unused `maps.dart`.
- Built out `home`/`profile`/`worldMap` to the same data/domain/presentation depth as `auth`, each against a real (mocked) endpoint rather than static/derived state.
- Added a mock case for `/users/me` (`ApiEndpoints.me`) — this also fixes a latent bug where `AuthController`'s background `refreshAuth()` (triggered whenever a cached session exists at startup) would 404 under `USE_MOCK=true` and silently sign the user back out, since that endpoint previously had no mock handler.
- Added widget tests (`test/features/*/presentation/pages/*_page_test.dart`) that pump each rebuilt page with mocked repositories and assert on rendered content + zero exceptions — the fastest way to catch a Flutter layout error (e.g. unbounded-height `Center`/`SingleChildScrollView` nesting, which was caught and avoided in `profile_page.dart` during this pass) without a live device.
- Disabled the `one_member_abstracts` lint project-wide (`analysis_options.yaml`) — it conflicts with the Repository/DataSource interface pattern the whole architecture depends on, since a new feature legitimately starts with one method per interface.
- Fixed several pre-existing `flutter analyze` infos (line length, doc-comment references, a missing `on` clause) that meant `flutter analyze` did not actually return a clean exit code before this pass, despite being a real CI gate.

## Known gaps vs. the `mapanytime-market-app` reference

- `worldMap` has no map SDK integrated — deferred by explicit choice, not oversight (see scoping note above).
- No socket/realtime datasource pattern demonstrated (reference app uses this for `notifications`/`worldMap`).
- No CI step to regenerate/verify test coverage thresholds — `flutter test` gates pass/fail only, not coverage.

## What's intentionally *not* copied from the reference app

- Freezed/codegen models — the reference app's own engineering handbook claims Freezed but the app doesn't actually use it (verified: no `freezed`/`json_serializable` dependency, no generated files). This template's manual `fromJson`/`toJson` approach is simpler and should stay.
- The reference app's "CI feature-isolation gate" claim, which doesn't exist in its actual CI — this template already has the real version, so nothing to import there.
