# Hiww mobile app

Flutter client for the Hiww marketplace, targeting **iOS, Android and web**. It
talks to the existing backend (`../src`) — no backend changes are required.

Current scope (through phase D1): a consumer-grade design system, themed
authentication, the **Browse / My Trips / My Wants / Inbox** app shell, and an
Account screen with a working ID-check submission. The marketplace flows
(feed, post-a-want, offers, order tracker, chat) are styled placeholders and land
in phases D2–D6 (see [../docs/MOBILE.md](../docs/MOBILE.md)).

## Prerequisites

- Flutter stable (3.47+) — `flutter doctor`
- The Hiww backend running locally: from the repo root
  `npm run db:setup && npm run dev` (serves `http://localhost:3000`)

## Setup

```bash
cd mobile
flutter pub get
```

## Run

| Target | Command |
|---|---|
| Web (Chrome) | `flutter run -d chrome` |
| Android emulator | `flutter run -d emulator-5554` |
| iOS simulator (macOS) | `flutter run -d ios` |

### Pointing at the backend

The base URL is resolved in [lib/core/env.dart](lib/core/env.dart):

- web / iOS simulator / desktop → `http://localhost:3000`
- Android emulator → `http://10.0.2.2:3000` (its alias for the host machine)
- **physical device** or a hosted API → pass it explicitly:

```bash
flutter run -d <device> --dart-define=HIWW_API_BASE_URL=http://192.168.1.20:3000
```

## Checks

```bash
flutter analyze
flutter test
flutter build web        # sanity-check the release build
```

### End-to-end test (needs the real backend)

```bash
# terminal 1 — from the repo root
npm run db:setup && npm run dev
# terminal 2 — here
flutter test -d flutter-tester integration_test/app_flow_test.dart
```

Drives the real app (go_router + Dio over sockets) through register → Browse →
post a want. Runs on the flutter-tester VM — no device or chromedriver. It is
not part of plain `flutter test`; it fails fast with instructions if the API on
`localhost:3000` is unreachable.

## Regenerating brand assets

```bash
dart run tool/gen_icon.dart              # redraw the "H." source art
dart run flutter_launcher_icons          # launcher icons (android/ios/web)
dart run flutter_native_splash:create    # native splash (android/ios)
```

The web loader is hand-written in `web/index.html` (native-splash `web: false`).

## Architecture

- **State / DI** — `flutter_riverpod`
- **Navigation** — `go_router` with an auth-aware `redirect`
- **HTTP** — `dio`, wrapped by `ApiClient` which attaches the bearer token,
  unwraps the `{ success, data, code }` envelope and normalises errors to
  `ApiException`
- **Token storage** — `flutter_secure_storage`
- **Design** — `theme/` (Material 3 + `HiwwColors` extension, Plus Jakarta Sans)
  and `ui/` (shared widgets); tokens modelled on the product mockup

```
lib/
  core/        env, api client, secure token storage, formatting helpers
  theme/       colour tokens + ThemeData (light/dark)
  ui/          shared presentational widgets (cards, avatar, pills, stars…)
  routing/     go_router config + auth redirect
  features/
    auth/      data / domain / application (AsyncNotifier) / presentation
    shell/     app shell (nav rail / bottom bar), splash, tab placeholders
    account/   profile + ID-check
```
