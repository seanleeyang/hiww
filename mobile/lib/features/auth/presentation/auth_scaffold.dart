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
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      const Center(child: BrandMark(fontSize: 30)),
                      const SizedBox(height: 32),
                      Text(title, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
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
            const Positioned(top: 4, right: 8, child: _LanguageToggle()),
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends ConsumerWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final chosen = ref.watch(localeControllerProvider).valueOrNull;
    final current = chosen?.languageCode ?? Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;

    Widget option(String code, String label) {
      final active = current == code;
      return TextButton(
        onPressed: active
            ? null
            : () => ref.read(localeControllerProvider.notifier).setLocale(Locale(code)),
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: active ? scheme.primary : scheme.onSurfaceVariant,
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        option('en', l10n.languageEnglish),
        Text('|', style: TextStyle(color: scheme.outlineVariant)),
        option('th', l10n.languageThai),
      ],
    );
  }
}
