import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../application/auth_controller.dart';
import 'auth_form_field.dart';
import 'auth_scaffold.dart';

/// Shown right after registration until both `email` and `phone` are
/// confirmed — the backend blocks every other route until then (see
/// `src/middleware/auth-guard.ts`'s VERIFICATION_EXEMPT_ROUTES).
class VerifyOtpScreen extends ConsumerWidget {
  const VerifyOtpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return AuthScaffold(
      title: 'Verify your account',
      subtitle: "We've sent a 6-digit code to your email and phone number.",
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user != null) ...[
            _ChannelSection(channel: 'email', destination: user.email, verified: user.emailVerified),
            const SizedBox(height: 20),
            _ChannelSection(channel: 'phone', destination: user.phone ?? '', verified: user.phoneVerified),
          ],
        ],
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Wrong details?'),
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
  }
}

class _ChannelSection extends ConsumerStatefulWidget {
  const _ChannelSection({required this.channel, required this.destination, required this.verified});
  final String channel;
  final String destination;
  final bool verified;

  @override
  ConsumerState<_ChannelSection> createState() => _ChannelSectionState();
}

class _ChannelSectionState extends ConsumerState<_ChannelSection> {
  final _code = TextEditingController();
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _info;
  String? _devCode;

  @override
  void initState() {
    super.initState();
    // Registration already sent a code, but there's no UI-free way to know
    // it without a real inbox/phone (no SMS/email provider is wired up yet
    // — see src/services/otp/). Ask for a fresh one right away so the dev
    // hint below is populated without an extra tap.
    if (!widget.verified) _resend(showSentMessage: false);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(channel: widget.channel, code: _code.text.trim());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend({bool showSentMessage = true}) async {
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      final devCode = await ref.read(authControllerProvider.notifier).resendOtp(channel: widget.channel);
      if (!mounted) return;
      setState(() {
        _devCode = devCode;
        if (devCode != null) _code.text = devCode;
        if (showSentMessage && devCode == null) _info = 'A new code was sent.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.channel == 'email' ? 'Email' : 'Phone';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.verified ? Icons.check_circle : Icons.radio_button_unchecked,
              color: widget.verified ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label · ${widget.destination}',
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (!widget.verified) ...[
          if (_devCode != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'No SMS/email provider is set up yet — dev code $_devCode has been filled in for you.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          AuthFormField(
            controller: _code,
            label: '6-digit code',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _verify,
              child: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verify'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _resending ? null : _resend,
              child: Text(_resending ? 'Sending…' : 'Resend code'),
            ),
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_info != null)
            Text(_info!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
