# Push notifications — Firebase Cloud Messaging

Real device push, not just the in-app notification feed. Backed by a real
Firebase project, `hiww-d1f5c`.

## Status

- **Android + Web: live.** Real config in `mobile/lib/firebase_options.dart`,
  `mobile/web/firebase-messaging-sw.js`, `mobile/android/app/google-services.json`.
  Backend has `PUSH_PROVIDER=fcm` + `FIREBASE_SERVICE_ACCOUNT_JSON` set in Render.
- **iOS: scaffolded, not functional yet.** The code is in place (see below) but
  `firebase_options.dart`'s `ios` block is still a placeholder, and the app can't
  even be built without a Mac — see "iOS setup" below for what's still needed.

## How it works

- `src/services/push/` — `PushSender` abstraction (mock/FCM), same pattern as
  the AI-analyzer and payment/identity provider abstractions.
- `src/services/push-notify.ts`'s `sendPush()` looks up every device token
  registered for a user (`device_tokens` table) and sends to all of them,
  pruning any the provider reports as dead/unregistered.
- `src/services/notify.ts`'s `recordNotification()` fires a push automatically
  whenever it writes an in-app notification row — every notification type gets
  push for free, no per-call-site wiring needed. Order chat messages push too,
  directly from `src/modules/messages/routes.ts` (they aren't stored as
  notification rows — Inbox has its own Messages tab for those).
- Mobile: `mobile/lib/features/push/` — `PushBootstrap` registers the device's
  token on sign-in, unregisters on sign-out, refreshes the in-app feed on a
  foreground push, and deep-links via the push payload's `link` field when tapped.
  Wrapped in try/catch everywhere so an unconfigured platform or denied
  permission degrades to "no push", never a crash.

## Backend env vars

```
PUSH_PROVIDER=fcm
FIREBASE_SERVICE_ACCOUNT_JSON=<the full JSON from Project settings -> Service accounts -> Generate new private key>
```

Leaving `PUSH_PROVIDER` unset (or anything but `fcm`) runs the mock sender —
logs instead of sending, no key needed. This is the default for local dev/tests.

**Set `FIREBASE_SERVICE_ACCOUNT_JSON` directly in your host's environment
variable UI (Render's Environment tab), never in this repo or in chat** — it's
a credential that can send push to every registered device.

## Adding/regenerating the Android + Web config

If you ever need to redo this (new Firebase project, lost config, etc.):

1. [console.firebase.google.com](https://console.firebase.google.com) → your project
   → Project Overview (or Project settings → **Your apps**) → the small platform
   icon row → **Android**.
2. Package name `com.hiww.hiww_mobile` (see `mobile/android/app/build.gradle.kts`'s
   `applicationId` — note this is snake_case, different from iOS's `com.hiww.hiwwMobile`).
   Download `google-services.json` → `mobile/android/app/google-services.json`.
3. Same icon row → **Web** (`</>`). Nickname doesn't matter. Copy the shown
   config object (`apiKey`, `appId`, `messagingSenderId`, `projectId`,
   `authDomain`, `storageBucket`) into `firebase_options.dart`'s `web` block
   and `firebase-messaging-sw.js`'s `firebase.initializeApp({...})` call.
4. Project settings → **Cloud Messaging** tab (can be hidden behind a narrow
   browser window — widen it if you don't see the tab) → **Web configuration**
   → **Generate key pair** under "Web Push certificates" → paste into
   `push_service.dart`'s `_webVapidKey`.

## iOS setup (still needed)

Two things outside this repo, then the code side:

1. **Apple Developer Program** — [developer.apple.com](https://developer.apple.com),
   ~$99/yr, approval can take a day or two. Required: a free/personal Apple ID
   cannot get the Push Notifications entitlement, paid-only.
2. **A Mac (or cloud Mac CI, e.g. Codemagic/MacStadium)** — Xcode only runs on
   macOS. There is no way to build, run, or test the iOS app from Windows.
   All the iOS wiring below is unverified until this exists.

Once both exist:

3. Firebase console → same platform-icon row → **iOS**. Bundle ID
   `com.hiww.hiwwMobile` (`ios/Runner.xcodeproj/project.pbxproj`'s
   `PRODUCT_BUNDLE_IDENTIFIER`). Download `GoogleService-Info.plist` →
   `mobile/ios/Runner/GoogleService-Info.plist`, and add it to the Xcode
   project (drag into the Runner group in Xcode's navigator so it's bundled —
   the file existing on disk alone isn't enough for Xcode to package it).
4. Apple Developer portal → **Certificates, Identifiers & Profiles → Keys** →
   create an APNs Auth Key (.p8), note its Key ID and your Team ID.
5. Firebase console → Project settings → **Cloud Messaging** tab → **Apple app
   configuration** → upload that .p8 key + Key ID + Team ID.
6. Fill in `firebase_options.dart`'s `ios` block (`apiKey`, `appId` — both from
   `GoogleService-Info.plist`).
7. In Xcode: open `ios/Runner.xcworkspace`, select the Runner target →
   **Signing & Capabilities** → confirm **Push Notifications** and **Background
   Modes → Remote notifications** are both present (already wired via
   `ios/Runner/Runner.entitlements` and `Info.plist`'s `UIBackgroundModes` —
   Xcode should just show them as already enabled, not need re-adding) and that
   signing is set to a team under the paid Apple Developer account.
8. `flutter build ios` / run on a real device (push doesn't work in the
   Simulator — Apple's APNs sandbox needs a physical device) to verify.

## Verifying it's actually sending real pushes, not the mock

This bit us before with the AI receipt-check key: an unset/wrong credential
falls back to the mock silently, no error anywhere. To check:

1. Fresh/incognito browser tab (dodges a stale service-worker cache) →
   `hiww.pages.dev` → sign in → allow the notification permission prompt.
2. Trigger any event that pushes (accept an offer, send a chat message, etc.).
3. You should get a real OS-level notification even if the tab isn't focused.
   If nothing arrives, check: Render's `FIREBASE_SERVICE_ACCOUNT_JSON` is valid
   JSON with no truncation, `PUSH_PROVIDER=fcm` is actually set, and the
   `_webVapidKey` matches the project's current Web Push certificate.
