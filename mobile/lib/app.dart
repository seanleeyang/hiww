import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/settings/locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

/// Lets the mouse drag-scroll on web/desktop (off by default in Flutter).
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Root widget. Owns the [MaterialApp.router] and wires in the go_router
/// instance that reacts to authentication state.
class HiwwApp extends ConsumerWidget {
  const HiwwApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeControllerProvider).valueOrNull;
    return MaterialApp.router(
      title: 'Hiww',
      debugShowCheckedModeBanner: false,
      theme: hiwwTheme(Brightness.light),
      darkTheme: hiwwTheme(Brightness.dark),
      scrollBehavior: _AppScrollBehavior(),
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
