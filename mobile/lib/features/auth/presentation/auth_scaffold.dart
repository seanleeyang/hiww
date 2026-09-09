import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/brand_mark.dart';
import '../../../ui/language_toggle.dart';

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
      appBar: Navigator.of(context).canPop()
          ? AppBar(backgroundColor: Colors.transparent, elevation: 0)
          : null,
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
                      const LanguageToggle(),
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
