import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Apple/Facebook/Google sign-in buttons, shared by the landing, login and
/// register screens. None of the three providers are wired up to a real
/// OAuth flow yet (that needs credentials only the project owner can obtain
/// — see the go-live plan), so every button currently just explains that.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({super.key});

  void _notConfigured(BuildContext context, String provider) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.errorSocialNotConfigured(provider))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => _notConfigured(context, l10n.providerApple),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.apple),
          label: Text(l10n.actionSignInApple),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => _notConfigured(context, l10n.providerFacebook),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1877F2),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.facebook),
          label: Text(l10n.actionContinueFacebook),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _notConfigured(context, l10n.providerGoogle),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
          icon: const _GoogleMark(),
          label: Text(l10n.actionSignInGoogle),
        ),
      ],
    );
  }
}

/// Flutter's Material icon set has no Google logo glyph — a simple lettermark
/// in Google's blue stands in until real branding assets are added.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF4285F4),
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          height: 1,
        ),
      ),
    );
  }
}

/// The "or use your email" divider shown between the social buttons and the
/// email form.
class SocialAuthDivider extends StatelessWidget {
  const SocialAuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              l10n.dividerOrUseEmail,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Expanded(child: Divider(color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}
