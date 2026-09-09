import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/locale_controller.dart';
import '../l10n/app_localizations.dart';

/// "English | ไทย" switcher shown on every screen a signed-out person might
/// reach before they can read the app in their language: the onboarding
/// carousel, the landing screen, and login/register/verify (via
/// `AuthScaffold`). Renders both options as one paragraph (rather than two
/// separate Text/Button widgets side by side) so they share a single text
/// baseline — Thai script's line-height metrics differ enough from Latin
/// that laying them out as independent boxes made "ไทย" sit visibly higher
/// than "English" even when the row centered them.
class LanguageToggle extends ConsumerStatefulWidget {
  const LanguageToggle({super.key});

  @override
  ConsumerState<LanguageToggle> createState() => _LanguageToggleState();
}

class _LanguageToggleState extends ConsumerState<LanguageToggle> {
  final _enTap = TapGestureRecognizer();
  final _thTap = TapGestureRecognizer();

  @override
  void initState() {
    super.initState();
    _enTap.onTap = () => _setLocale('en');
    _thTap.onTap = () => _setLocale('th');
  }

  void _setLocale(String code) =>
      ref.read(localeControllerProvider.notifier).setLocale(Locale(code));

  @override
  void dispose() {
    _enTap.dispose();
    _thTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chosen = ref.watch(localeControllerProvider).valueOrNull;
    final current = chosen?.languageCode ?? Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

    TextStyle styleFor(bool active) => base.copyWith(
          color: active ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: l10n.languageEnglish,
            style: styleFor(current == 'en'),
            recognizer: current == 'en' ? null : _enTap,
          ),
          TextSpan(text: ' | ', style: TextStyle(color: scheme.outlineVariant)),
          TextSpan(
            text: l10n.languageThai,
            style: styleFor(current == 'th'),
            recognizer: current == 'th' ? null : _thTap,
          ),
        ],
      ),
    );
  }
}
