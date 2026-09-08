import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/brand_mark.dart';
import 'social_auth_buttons.dart';

/// First screen a signed-out person sees (after the one-time onboarding
/// carousel): social sign-in, an email path into login/register, and a
/// guest link into Browse. See `app_router.dart` for how it's reached.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  const SizedBox(height: 24),
                  const Center(child: BrandMark(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text(
                    l10n.landingTagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 40),
                  const SocialAuthButtons(),
                  const SocialAuthDivider(),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => context.push('/register'),
                          child: Text(l10n.actionCreateAccountButton),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push('/login'),
                          child: Text(l10n.actionLogIn),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/browse'),
                      child: Text(l10n.actionExploreGuest),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
