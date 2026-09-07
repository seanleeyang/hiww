import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/locale_storage.dart';

/// The chosen app language. `null` means "follow the system locale" —
/// falls back to English via `AppLocalizations`' default resolution.
class LocaleController extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() async {
    final code = await ref.read(localeStorageProvider).read();
    return code == null ? null : Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    state = AsyncData(locale);
    if (locale != null) {
      await ref.read(localeStorageProvider).write(locale.languageCode);
    }
  }
}

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, Locale?>(LocaleController.new);
