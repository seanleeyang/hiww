import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routing/app_router.dart';
import '../auth/application/auth_controller.dart';
import '../notifications/data/notifications_repository.dart';
import 'push_service.dart';

/// Wires Firebase Cloud Messaging into the app's lifecycle. Only ever
/// mounted when `Firebase.initializeApp()` actually succeeded (see
/// `main.dart`) — every FCM call in here would otherwise throw
/// `[core/no-app]` against a placeholder/missing project config.
///
/// - Registers this device whenever a user signs in; unregisters on sign-out.
/// - A push that arrives while the app is in the foreground doesn't show a
///   system banner on its own, so this just refreshes the in-app
///   notification feed instead of trying to fake one.
/// - Tapping a push (background or cold-start) deep-links via the same
///   `link` field the in-app notification list already uses.
class PushBootstrap extends ConsumerStatefulWidget {
  const PushBootstrap({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<PushBootstrap> createState() => _PushBootstrapState();
}

class _PushBootstrapState extends ConsumerState<PushBootstrap> {
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<String>? _refreshSub;
  String? _registeredForUserId;

  @override
  void initState() {
    super.initState();

    if (!ref.read(pushServiceProvider).supportsPush) return;

    _foregroundSub = FirebaseMessaging.onMessage.listen((_) {
      ref.invalidate(notificationsProvider);
    });
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_openLink);
    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      if (_registeredForUserId != null) {
        ref.read(pushServiceProvider).registerForCurrentUser();
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null && mounted) _openLink(message);
    });

    ref.listenManual(currentUserProvider, (previous, next) {
      if (next != null && next.id != _registeredForUserId) {
        _registeredForUserId = next.id;
        ref.read(pushServiceProvider).registerForCurrentUser();
      } else if (next == null && _registeredForUserId != null) {
        _registeredForUserId = null;
        ref.read(pushServiceProvider).unregister();
      }
    }, fireImmediately: true);
  }

  void _openLink(RemoteMessage message) {
    final link = message.data['link'];
    if (link is String && link.isNotEmpty) {
      ref.read(routerProvider).go(link);
    }
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    _openedSub?.cancel();
    _refreshSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
