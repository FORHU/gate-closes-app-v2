# 🏢 Flutter Frontend Engineering Handbook
**System Name:** Flutter Architecture Enforcement Framework

This document defines the official frontend engineering standards, architecture rules, and development workflow for all Flutter applications built on this system.

---

## 🧠 1. Purpose of This System

This framework exists to ensure that all Flutter applications built within the organization are:
- **Predictable** in structure
- **Safe** in error handling
- **Consistent** in UI design
- **Scalable** across teams
- **Testable** by default
- **Enforced** by tooling where practical, and by code review elsewhere

> Not every rule below is mechanically enforced. Formatting, linting, tests, and
> feature isolation are checked in CI (see §10); design-system and
> no-API-in-UI rules are enforced by review. Each rule notes which applies.

---

## 🚫 2. Engineering Principles (Non-Negotiable)

These principles are enforced across all features:

### 2.1 No Unstructured State
- All state must be managed via Riverpod (or equivalent controller layer)
- No global mutable state allowed

### 2.2 No Unhandled Exceptions in UI Layer
- UI must never use raw `try/catch`
- All errors must be represented via: `Either<Failure, T>`

### 2.3 No Hardcoded UI Values
- No raw spacing, colors, or typography
- All UI must use design tokens and shared components

### 2.4 Strict Feature Isolation
- Features must not directly depend on each other
- Cross-feature imports are forbidden *(CI-enforced — see §10)*
- **One sanctioned exception:** the `auth` feature owns app-wide
  session/identity state (the authenticated `UserEntity`). Other features may
  import `auth`; `auth` must not import any other feature. No other
  feature-to-feature imports are allowed.

### 2.5 API Access Control
- All network access must go through `ApiService`
- Direct HTTP/Dio usage outside core is not allowed

---

## 🏗️ 3. Architecture Model

### 3.1 Feature-First Structure
All code is organized by feature:
```text
lib/
  features/
    auth/
      data/
      domain/
      presentation/
    home/
      data/
      domain/
      presentation/
```

### 3.2 Layer Responsibilities
| Layer | Responsibility | Rules |
|---|---|---|
| **Presentation** | UI + State interaction | No business logic |
| **Controller** | State orchestration | Must handle Either |
| **Domain** | Contracts & entities | Pure Dart only |
| **Data** | API / DB implementation | Implements domain contracts |

### 3.3 Dependency Flow
`UI → Controller → Domain → Data → Core Services`

> [!CAUTION]
> **Reverse dependency is strictly forbidden.**

---

## 🔁 4. Request Lifecycle

Every user interaction follows this flow:
1. UI triggers controller action
2. Controller sets loading state
3. Repository is called
4. API request is executed via `ApiService`
5. Response is mapped to `Either`
6. Controller handles success/failure explicitly
7. UI reacts to state update

---

## 🛡️ 5. Error Handling Standard

### 5.1 Core Principle
**Errors are data, not exceptions.**

### 5.2 Repository Contract
```dart
Future<Either<Failure, Entity>> login();
```

### 5.3 Controller Handling Rule
```dart
result.fold(
  (failure) => handleFailure(failure),
  (success) => handleSuccess(success),
);
```

### 5.4 Forbidden Pattern
```dart
try {
  await api.login();
} catch (e) {
  // ❌ Not allowed in architecture
}
```

---

## 🎨 6. Design System Enforcement

### 6.1 UI Rule
**UI consistency is enforced, not optional.**

### 6.2 Spacing System
```dart
const Gap(AppSpacing.md);
AppSpacing.md.v; // vertical gap
AppSpacing.edgeInsetsLg;
```

### 6.3 Allowed Components Only
- `PrimaryButton` / `GradientButton`
- `ModernTextField`
- `GlassCard`

### 6.4 Forbidden UI Patterns
- Raw `SizedBox(height: x)`
- Inline colors
- Direct `TextStyle()` usage outside theme system

---

## 🌐 7. Networking Rules

### 7.1 API Layer
All requests must go through: `ApiService` (Dio abstraction), which exposes
`get` / `post` / `put` / `patch` / `delete`.

### 7.2 Responsibilities
- Token injection + transparent refresh-on-401 (`AuthInterceptor`)
- Retry handling (`dio_smart_retry`)
- Error normalization — Dio transport errors become typed `AppException`s
  (`NetworkException`, `UnauthorizedException`, `ServerException`)
- Logging control (dev only)

### 7.3 Error Translation Contract
- **Data layer** (`ApiService`/data sources) throws `AppException` subtypes.
- **Repositories** catch them and return typed `Failure`s
  (`NetworkFailure`, `UnauthorizedFailure`, `ServerFailure`).
- Exceptions never reach controllers or the UI.

### 7.4 Mock Backend (runs with no server)
- When `AppConfig.instance.useMock` is true (dev default), a `MockInterceptor`
  serves canned responses. Set `USE_MOCK=false` to hit the real `BASE_URL`.
- The mock sits inside the Dio pipeline, so the real `ApiService` path is always
  exercised — removing it requires no other code changes.

### 7.5 Forbidden
- Direct Dio usage in features
- HTTP calls in UI or controller layers
- Inlining endpoint path strings — add them to `ApiEndpoints`

---

## 🌍 8. Localization Standard

### 8.1 System
- Flutter ARB-based localization (`flutter gen-l10n`)
- `context.l10n` extension

### 8.2 Rule
> [!WARNING]
> **No hardcoded user-facing strings allowed.**

---

## 🧪 9. Testing Standard

### 9.1 Required Pattern: AAA
- **A**rrange
- **A**ct
- **A**ssert

### 9.2 Testing Scope
| Component | Required |
|---|---|
| Controllers | ✅ Yes |
| Repositories | ✅ Yes |
| UI Widgets | ⚠️ Optional |

### 9.3 Example
```dart
test('should return user on successful login', () async {
  // Arrange
  when(() => repo.login(any(), any()))
      .thenAnswer((_) async => Right(testUser));

  // Act
  await controller.login(email, password);

  // Assert
  expect(state.user, testUser);
});
```

---

## ⚙️ 10. CI/CD Enforcement Layer

### 10.1 Pipeline Gates
All code must pass these **mechanically enforced** gates:
- `dart format` (formatting)
- `flutter analyze` (`very_good_analysis` lints)
- Feature-isolation guard (no cross-feature imports except `auth`)
- `flutter test`

### 10.2 Enforcement Rule
> [!IMPORTANT]
> **Code that fails a CI gate cannot be merged into main.**

### 10.3 Review-Enforced Rules
The following are standards but are **not** mechanically checked — reviewers are
responsible for them:
- design-system tokens (no hardcoded spacing/colors/typography)
- no API calls or raw HTTP in the UI/controller layers
- no hardcoded user-facing strings (use `context.l10n`)

---

## 🚫 11. Anti-Pattern Registry

The following are explicitly forbidden:

**Architecture Violations**
- ❌ API calls inside UI
- ❌ Business logic inside widgets
- ❌ Cross-feature imports

**State Violations**
- ❌ Global mutable state
- ❌ Uncontrolled side effects

**UI Violations**
- ❌ Hardcoded spacing
- ❌ Inline styling
- ❌ Duplicated UI components

---

## 📦 12. Feature Development Workflow

- **Step 1:** Create Feature Folder (`features/new_feature/`)
- **Step 2:** Implement Layers (domain first -> data second -> controller third -> UI last)
- **Step 3:** Add tests (controller test required, repository test required)
- **Step 4:** Validate (`flutter analyze`, `flutter test`)

---

## 🧠 13. Engineering Guarantee Model

**This system guarantees:**
- consistent architecture boundaries
- enforced error handling contracts
- standardized UI structure
- predictable state flow
- CI-enforced quality gates

**It does NOT guarantee:**
- correctness of business logic
- absence of runtime bugs in external APIs

---

## 🏁 14. Final Statement

> This system is not a template.
> It is an engineering enforcement framework for Flutter frontend development, designed to ensure predictable scaling across multiple developers and long-term codebase stability.
