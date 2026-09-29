# Flutter Design System & Backend Integration

This document outlines the **ink-on-white** design system aligned with `mapanytime-app` (v3.44.8) and the backend API integration for `flutter_template_v1`.

---

## 🎨 1. Ink-on-White Design System

The application styling follows a minimalist, high-contrast ink-on-white aesthetic. All legacy neon glow blobs and dark gradient surfaces have been removed.

### Design Tokens (`lib/theme/tokens/colors.dart`)
* **Background Canvas**: `#F7F7F8` (`AppColors.ui.background`)
* **Surface Cards**: `#FFFFFF` (`AppColors.ui.surface`) with `#ECEDF0` hairline border and `24px` radius.
* **Ink Accent / Primary**: `#0D0D0F` (`AppColors.ink.primary`)
* **Text**:
  * Primary: `#14161C` (`AppColors.text.primary`)
  * Secondary: `#6B7280` (`AppColors.text.secondary`)
  * Tertiary: `#9AA0AE` (`AppColors.text.tertiary`)
  * Inverse: `#FFFFFF` (`AppColors.text.inverse`)

### UI Components
* **Pill Buttons (`PrimaryButton`)**:
  * Background: `#0D0D0F` (ink)
  * Radius: Fully rounded pill (`AppRadius.pill = 999px`)
  * Text: White (`#FFFFFF`, `FontWeight.w600`)
  * Height: 52px default
* **Input Fields (`ModernTextField`)**:
  * Fill: `#F5F5F6` with `20px` radius
  * Border: Focused 2px `#0D0D0F`, unfocused transparent hairline
  * Password reveal / suffix icons: `#9AA0AE`
* **Floating Capsule Navigation (`AnimatedBottomNavigation`)**:
  * Capsule surface: Pure white `#FFFFFF` floating pill (`AppColors.ui.surface`)
  * Active indicator: `#0D0D0F` ink icon with subtle tint pill background (`AppColors.ink.primary` with 0.08 alpha)
  * Inactive items: `#9AA0AE`
* **Login & Register Cards**:
  * Encapsulated in a `24px` rounded white card (`AppColors.ui.surface`)
  * Responsive wrap footers preventing overflow across narrow viewports

---

## 📡 2. Backend Integration

The app connects to the Express + PostgreSQL backend (`node-postg-backend-template`) running on port `3002`.

### Configuration (`.env.dev`)
```env
ENVIRONMENT=dev
APP_NAME=Flutter Template (Dev)
BASE_URL=http://localhost:3002/api/v1
ENABLE_LOGGING=true
```

### Running on Web
The Node backend whitelists `http://localhost:8085` in its CORS middleware. Always run Flutter Web on port `8085`:
```bash
flutter run -d chrome --web-port=8085
```

### Endpoints Hooked:
1. **Authentication**:
   * `POST /api/v1/login` (or `/api/v1/auth/login`)
   * Models automatically unwrap REST responses (`data.user`, `data.accessToken`).
2. **Quiz Engine**:
   * `GET /api/v1/quiz/questions` — Fetches 100 seeded questions from PostgreSQL.
   * `POST /api/v1/quiz/progress` — Syncs user score and answers to the backend.

---

## 🧪 3. Verification & Testing

Run all unit and widget tests:
```bash
flutter test
```
*Current test suite: **43 / 43 tests passing**.*
