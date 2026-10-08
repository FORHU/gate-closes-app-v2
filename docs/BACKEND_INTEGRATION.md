> ⚠️ **Probably legacy (2026-10-08):** this describes a template backend
> (Express + Prisma + PostgreSQL), not `gate-closes-api` (Express +
> MongoDB + Redis + Socket.IO). Kept until the System Discovery audit
> (`NEXT_SESSION.md`) classifies it.

# Flutter ↔ Node.js Backend Integration Guide

This guide documents how `flutter_template_v1` connects to `node-postg-backend-template` — the production Express + Prisma + PostgreSQL backend.

---

## 📡 Connection Overview

```
flutter_template_v1             node-postg-backend-template
  lib/core/config/               src/routes/
  app_config.dart  ─────────►   /api/v1/auth/*
  (BASE_URL env)                 /api/v1/users/*
                                 /api/v1/posts/*
```

The Flutter app reads `BASE_URL` from the environment file (`.env.dev` / `.env.prod`) via `flutter_dotenv`. The default dev value points directly at the backend:

```
BASE_URL=http://localhost:3002/api/v1
```

---

## ⚙️ Step-by-Step Setup

### 1. Start the backend

```bash
cd node-postg-backend-template

# Copy and fill in environment variables
cp .env.example .env

# Start PostgreSQL + Redis via Docker
docker compose up -d

# Install dependencies and run migrations
pnpm install
pnpm run db:setup

# Start the dev server (port 3002)
pnpm run dev
```

### 2. Configure Flutter environment

Edit `flutter_template_v1/.env.dev`:

```env
ENVIRONMENT=dev
APP_NAME=Flutter Template (Dev)
BASE_URL=http://localhost:3002/api/v1
ENABLE_LOGGING=true
```

> **Android emulator note**: Replace `localhost` with `10.0.2.2` when running on Android emulator, as `localhost` inside an emulator refers to the emulator's loopback, not your host machine:
> ```
> BASE_URL=http://10.0.2.2:3002/api/v1
> ```

### 3. Run the Flutter app

```bash
cd flutter_template_v1
flutter run --target lib/main_dev.dart
```

---

## 🔐 Authentication Flow

The Flutter app implements the same **JWT token protocol** defined in the ecosystem auth contract:

| Step | Flutter (Client) | Node Backend |
| :--- | :--- | :--- |
| **Register** | `POST /api/v1/auth/register` | Hashes password with bcrypt, creates `User` + `Session` in DB |
| **Login** | `POST /api/v1/auth/login` | Returns `{ accessToken, refreshToken, user }` |
| **Store tokens** | `flutter_secure_storage` (keychain/keystore) | — |
| **Attach token** | Dio interceptor adds `Authorization: Bearer <accessToken>` | — |
| **Token refresh** | `POST /api/v1/auth/refresh-token` with `refreshToken` | Rotates token pair, invalidates old session |
| **Logout** | `POST /api/v1/auth/logout` | Deletes session from DB + Redis |
| **Get profile** | `GET /api/v1/users/me` | Returns user identity from Bearer token |

### Token Storage

Flutter uses `flutter_secure_storage` which maps to platform-native secure storage:
- **iOS**: Keychain
- **Android**: Android Keystore / EncryptedSharedPreferences
- **Desktop**: OS credential manager

This is **more secure** than the web templates' `sessionStorage`.

---

## 🔄 API Response Contract

All responses from the backend follow this standard envelope:

```json
{
  "status": "success",
  "statusCode": 200,
  "data": { ... },
  "message": "Operation successful"
}
```

Error responses:

```json
{
  "status": "error",
  "statusCode": 401,
  "message": "Unauthorized: invalid token"
}
```

These are mapped in `lib/core/errors/` using `fpdart`'s `Either<Failure, T>` pattern.

---

## 🌐 CORS Configuration

The backend's `CORS_ORIGIN` environment variable must include the Flutter web origin (if running as Flutter Web):

```env
# node-postg-backend-template/.env
CORS_ORIGIN=http://localhost:4200,http://localhost:3000,http://localhost:5173,http://localhost:4000
```

For native mobile apps (iOS/Android), CORS is not enforced — native HTTP clients are not browser-bound.

---

## 🔧 Tenant Header

The backend uses `x-tenant-id` to support multi-tenancy. The Flutter app should attach:

```dart
// Add to Dio base options or interceptor
options.headers['x-tenant-id'] = 'flutter-v1';
```

---

## 📦 Key Flutter Packages Used

| Package | Role |
| :--- | :--- |
| `dio` | HTTP client with interceptors |
| `dio_smart_retry` | Auto-retry on network failure |
| `flutter_secure_storage` | Secure JWT token persistence |
| `flutter_dotenv` | Reads `.env.dev` / `.env.prod` at runtime |
| `fpdart` | `Either<Failure, T>` error modeling for API responses |
| `flutter_riverpod` | State management (auth state, user session) |
