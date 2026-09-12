import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'features/push/push_bootstrap.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads CLDR date-symbol data for every locale (Thai month/day names
  // among them) — required before any `DateFormat(pattern, 'th')` call, or
  // it throws "Locale data has not been initialized". Cheap enough with
  // only two supported locales that initializing all of them (the no-arg
  // form) is simpler than tracking which ones are actually needed.
  await initializeDateFormatting();

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
