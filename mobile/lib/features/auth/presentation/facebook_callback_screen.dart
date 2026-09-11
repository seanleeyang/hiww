import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/facebook_auth.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';

/// Landing point for Facebook's OAuth redirect
/// (`/facebook-callback?code=...&state=...`, or `?error=...` if the user
/// declined). There's no lasting UI here — just a brief spinner while the
/// code is exchanged for a session, then a bounce to `/browse` (success) or
/// `/landing` (failure, with a snackbar explaining why). Mirrors
/// `LineCallbackScreen` exactly — same OAuth redirect shape.
class FacebookCallbackScreen extends ConsumerStatefulWidget {
  const FacebookCallbackScreen({super.key, this.code, this.state, this.error});

  final String? code;
  final String? state;
  final String? error;

  @override
  ConsumerState<FacebookCallbackScreen> createState() => _FacebookCallbackScreenState();
}

class _FacebookCallbackScreenState extends ConsumerState<FacebookCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context)!;
    final expectedState = consumeFacebookOauthState();
    final code = widget.code;
    String? error;

    final stateMismatch =
        widget.error != null || code == null || widget.state == null || widget.state != expectedState;

    if (stateMismatch) {
      error = l10n.errorSocialSignInFailed;
    } else {
      await ref.read(authControllerProvider.notifier).socialLogin(
            provider: 'facebook',
            idToken: code,
            redirectUri: facebookRedirectUri(),
          );
      if (!mounted) return;
      final result = ref.read(authControllerProvider);
      if (result.hasError) {
        error = result.error is ApiException
            ? (result.error as ApiException).message
            : l10n.errorSocialSignInFailed;
      }
    }

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
    context.go(error == null ? '/browse' : '/landing');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
