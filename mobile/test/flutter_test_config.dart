import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// Flutter's test runner picks this up automatically for every test file
/// under `test/` — no per-file import needed. Loads CLDR date-symbol data
/// (Thai month/day names among them) before any test runs, since
/// `core/format.dart`'s `DateFormat(pattern, locale)` calls throw
/// `LocaleDataException` otherwise. In the real app this happens once in
/// `main()`; tests never call `main()`, so it has to happen here instead.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting();
  await testMain();
}
