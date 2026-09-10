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
/// iOS is included here but stays a no-op in practice until
/// `firebase_options.dart`'s `ios` placeholder is replaced with a real
/// config — `getToken()` throws on the placeholder, which the catch below
/// just swallows like any other unconfigured-project failure.
class PushService {
  PushService(this._ref);
  final Ref _ref;

  String? _registeredToken;

  bool get supportsPush =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Firebase Web Push VAPID key (Project settings -> Cloud Messaging ->
  /// Web configuration), required for `getToken()` to succeed on Web.
  static const String _webVapidKey =
      'BEDs7obKvRQx3jTuY9J4s6VTVuT_hYXDFuX0YmogGth4vi6vS_NKy50M84XYi0GPVxrwjRKaD6Z8C75qFekARlA';

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

      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android';
      await _ref.read(pushRepositoryProvider).registerToken(token: token, platform: platform);
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
