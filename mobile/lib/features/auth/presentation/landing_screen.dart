import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/brand_mark.dart';
import '../../../ui/language_toggle.dart';
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
    final returnTo = GoRouterState.of(context).uri.queryParameters['returnTo'];
    String withReturnTo(String path) => returnTo == null
        ? path
        : '$path?returnTo=${Uri.encodeComponent(returnTo)}';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                child: LanguageToggle(),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Center(child: BrandMark(fontSize: 36)),
                        const SizedBox(height: 10),
                        Text(
                          l10n.landingTagline,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 40),
                        const SocialAuthButtons(),
                        const SocialAuthDivider(),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => context.push(withReturnTo('/register')),
                                child: Text(l10n.actionCreateAccountButton),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => context.push(withReturnTo('/login')),
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
                        const SizedBox(height: 12),
                        _TermsFooter(l10n: l10n, scheme: scheme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "By using Hiww, I agree to Hiww's Terms of Use and Privacy Policy." —
/// styled to look like a link, but there's no real page to send it to yet,
/// so it's plain text rather than a dead tap target.
class _TermsFooter extends StatelessWidget {
  const _TermsFooter({required this.l10n, required this.scheme});
  final AppLocalizations l10n;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final link = muted.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w600,
    );
    return Text.rich(
      TextSpan(
        style: muted,
        children: [
          TextSpan(text: '${l10n.landingTermsPrefix} '),
          TextSpan(text: l10n.actionTermsOfUse, style: link),
          TextSpan(text: ' ${l10n.landingTermsAnd} '),
          TextSpan(text: l10n.actionPrivacyPolicy, style: link),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
