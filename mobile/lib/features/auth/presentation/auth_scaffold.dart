import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/brand_mark.dart';
import '../../settings/locale_controller.dart';

/// Shared shell for the login, register and verify-OTP screens: a warm hero
/// strip, the wordmark, a title/subtitle and a card holding the form. Also
/// carries the language toggle, since this is the first thing a signed-out
/// user sees and they need to be able to read it before they can log in.
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const Center(child: BrandMark(fontSize: 30)),
                  const SizedBox(height: 32),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      const _LanguageToggle(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  form,
                  const SizedBox(height: 8),
                  footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders both language options as one paragraph (rather than two separate
/// Text/Button widgets side by side) so they share a single text baseline —
/// Thai script's line-height metrics differ enough from Latin that laying
/// them out as independent boxes made "ไทย" sit visibly higher than
/// "English" even when the row centered them.
class _LanguageToggle extends ConsumerStatefulWidget {
  const _LanguageToggle();

  @override
  ConsumerState<_LanguageToggle> createState() => _LanguageToggleState();
}

class _LanguageToggleState extends ConsumerState<_LanguageToggle> {
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
