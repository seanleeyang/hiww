// Android + Web are wired up to the real `hiww-d1f5c` Firebase project.
//
// iOS is scaffolded but still PLACEHOLDER — the `ios` block below needs
// replacing before iOS push will work. Two things have to happen first,
// both outside this repo:
//   1. Enroll in the Apple Developer Program (developer.apple.com, ~$99/yr,
//      approval can take a day or two) — iOS push requires a paid account,
//      a free/personal Apple ID can't get the Push Notifications entitlement.
//   2. Add an iOS app to the `hiww-d1f5c` Firebase project (bundle ID
//      `com.hiww.hiwwMobile` — see `ios/Runner.xcodeproj/project.pbxproj`'s
//      `PRODUCT_BUNDLE_IDENTIFIER`, note the different casing from Android's
//      `com.hiww.hiww_mobile`), download `GoogleService-Info.plist` into
//      `ios/Runner/`, then generate an APNs auth key in the Apple Developer
//      portal (Certificates, Identifiers & Profiles -> Keys) and upload it
//      under Firebase's Project settings -> Cloud Messaging -> Apple app
//      configuration.
// Building/testing the iOS app at all additionally needs a Mac (Xcode) or a
// cloud Mac CI (e.g. Codemagic) — this can't be done from Windows.
// `Firebase.initializeApp()` is wrapped in a try/catch in `main.dart`
// specifically so a placeholder config degrades to "push disabled" instead
// of crashing the app, so the other platforms are unaffected either way.
// See `docs/PUSH_NOTIFICATIONS.md` for the full setup guide.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform yet — '
          'this pilot only wires up Android, Web, and (once its placeholder is '
          'replaced) iOS. Run `flutterfire configure` to add another platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB38t8wRYjnigtEAgHZMbnesAi2-p-KyLw',
    appId: '1:696163754096:android:7068d270436c82aad114b5',
    messagingSenderId: '696163754096',
    projectId: 'hiww-d1f5c',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCej8Pm_1hEcleuNSiD3a-zvQJOXrX8h4s',
    appId: '1:696163754096:web:17e96c2165a97395d114b5',
    messagingSenderId: '696163754096',
    projectId: 'hiww-d1f5c',
    authDomain: 'hiww-d1f5c.firebaseapp.com',
    storageBucket: 'hiww-d1f5c.firebasestorage.app',
    // Web push additionally needs a VAPID key, generated in the Firebase
    // console under Project settings -> Cloud Messaging -> Web configuration
    // -> "Web Push certificates". Set it in
    // `lib/features/push/push_service.dart`'s `_webVapidKey` once you have one.
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '696163754096',
    projectId: 'hiww-d1f5c',
    storageBucket: 'hiww-d1f5c.firebasestorage.app',
    iosBundleId: 'com.hiww.hiwwMobile',
    // From GoogleService-Info.plist once the iOS app exists in Firebase —
    // see the file header above for the full setup order.
  );
}
