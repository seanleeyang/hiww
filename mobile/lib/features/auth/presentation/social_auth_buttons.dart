import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/google_web_button.dart';
import '../../../core/line_auth.dart';
import '../../../core/social_auth_config.dart';
import '../../../l10n/app_localizations.dart';
import '../application/google_auth_controller.dart';

/// LINE/Facebook/Google sign-in buttons, shared by the landing, login and
/// register screens. Google and LINE are wired to real sign-in flows;
/// Facebook isn't yet — that needs credentials only the project owner can
/// obtain (see the go-live plan), so its button just explains that.
class SocialAuthButtons extends ConsumerWidget {
  const SocialAuthButtons({super.key});

  void _notConfigured(BuildContext context, String provider) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.errorSocialNotConfigured(provider))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // Instantiates GoogleAuthController (if not already alive) so it starts
    // listening for sign-in events as soon as one of these screens is on
    // screen — needed even on web, where the button below is Google's own.
    ref.watch(googleAuthControllerProvider);
    ref.listen(googleAuthErrorProvider, (previous, next) {
      if (next == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next)));
      ref.read(googleAuthErrorProvider.notifier).state = null;
    });

    // GIS's `large` button renders at a fixed ~40px tall regardless of the
    // container it's given (Google's own spec: "about 40px tall", not
    // adjustable) — the other two are sized to match it exactly, rather
    // than the reverse, for the same reason the shape is matched to
    // Google's fixed `pill` below instead of the other way around.
    const buttonHeight = 40.0;
    // Google's GIS button also has a hard 400px *width* ceiling (the same
    // reason `.clamp(1, 400)` appears below) — invisible on a phone, where
    // the form's own 420px max-width is never actually reached, but real on
    // a desktop-width screen: the form happily stretches LINE/Facebook to
    // 420px while Google refuses to go past 400, a visible 20px gap. This
    // caps all three together so they never disagree.
    const buttonRowMaxWidth = 400.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: buttonRowMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: buttonHeight,
              child: FilledButton.icon(
                onPressed: kIsWeb
                    ? () => startLineLogin(lineChannelId)
                    : () => _notConfigured(context, l10n.providerLine),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF06C755),
                  foregroundColor: Colors.white,
                  // Matches the Google button below, which is pinned to GIS's
                  // `pill` shape — a fixed, height-relative radius Google
                  // doesn't let us match with an arbitrary corner value, so
                  // these two match themselves to it instead.
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                label: Text(l10n.actionSignInLine),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: buttonHeight,
              child: FilledButton.icon(
                onPressed: () => _notConfigured(context, l10n.providerFacebook),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.facebook),
                label: Text(l10n.actionContinueFacebook),
              ),
            ),
            const SizedBox(height: 10),
            if (kIsWeb)
              // The GIS SDK requires web sign-in to be triggered from a button
              // it renders itself — a custom OutlinedButton can't call
              // authenticate() interactively on this platform. GIS won't stretch
              // to fill a container on its own (unlike the FilledButtons above),
              // so its width is measured and passed in explicitly to match them;
              // its locale defaults to the browser/Google-account's own
              // language, so it's pinned to the app's chosen one instead — left
              // alone, a Thai phone shows an English app with a Thai Google
              // button.
              LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  height: buttonHeight,
                  child: renderGoogleButton(
                    width: constraints.maxWidth.clamp(1, 400),
                    locale: Localizations.localeOf(context).languageCode,
                  ),
                ),
              )
            else
              SizedBox(
                height: buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: () => ref
                      .read(googleAuthControllerProvider)
                      .signInWithCustomButton(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  icon: const _GoogleMark(),
                  label: Text(l10n.actionSignInGoogle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Flutter's Material icon set has no Google logo glyph — a simple lettermark
/// in Google's blue stands in on the non-web (custom-button) path until real
/// branding assets are added.
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
