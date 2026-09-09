import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_repository.dart';

/// Thin wrapper around Firebase Cloud Messaging: requests notification
/// permission, fetches this device's token, and registers it with the
/// backend. Deliberately best-effort everywhere — a denied permission
/// prompt, an unconfigured Firebase project (see `firebase_options.dart`),
/// or an unsupported platform should all degrade to "no push", never crash
/// the app or block sign-in.
///
/// Only wired up for Android and Web in this pilot — see
/// `firebase_options.dart` for why iOS isn't included yet.
class PushService {
  PushService(this._ref);
  final Ref _ref;

  String? _registeredToken;

  bool get supportsPush => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  /// Set this to your Firebase Web Push VAPID key (Project settings ->
  /// Cloud Messaging -> Web configuration) once you have one — required for
  /// `getToken()` to succeed on Web. Left null for now, which just means
  /// web push doesn't work until it's set; Android is unaffected.
  static const String? _webVapidKey = null;

  Future<void> registerForCurrentUser() async {
    if (!supportsPush) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await (kIsWeb
          ? messaging.getToken(vapidKey: _webVapidKey)
          : messaging.getToken());
      if (token == null || token == _registeredToken) return;

      await _ref.read(pushRepositoryProvider).registerToken(
            token: token,
            platform: kIsWeb ? 'web' : 'android',
          );
      _registeredToken = token;
    } catch (_) {
      // No Firebase project configured yet, permission plumbing missing on
      // this platform, or a transient network error — push is an
      // enhancement, never a hard requirement for using the app.
    }
  }

  Future<void> unregister() async {
    final token = _registeredToken;
    _registeredToken = null;
    if (token == null) return;
    try {
      await _ref.read(pushRepositoryProvider).unregisterToken(token);
    } catch (_) {
      // best-effort — a stale token left behind just means one fewer device
      // gets pushes until it naturally expires server-side.
    }
  }
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));
