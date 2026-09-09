import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/push/push_bootstrap.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Best-effort: `firebase_options.dart` ships with placeholder values until
  // a real Firebase project is wired up (see that file's setup steps). A
  // failure here just means push notifications are unavailable — never a
  // reason to keep the rest of the app from starting.
  var pushAvailable = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    pushAvailable = true;
  } catch (_) {
    // No real project configured yet, or this platform isn't set up.
  }

  runApp(ProviderScope(
    child: pushAvailable ? const PushBootstrap(child: HiwwApp()) : const HiwwApp(),
  ));
}
