import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/busy_filled_button.dart';
import '../application/auth_controller.dart';
import 'auth_form_field.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final email = _email.text.trim();
    try {
      final devCode =
          await ref.read(authControllerProvider.notifier).forgotPassword(email: email);
      if (!mounted) return;
      final query = <String, String>{'email': email};
      if (devCode != null) query['devCode'] = devCode;
      context.push(Uri(path: '/reset-password', queryParameters: query).toString());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AuthScaffold(
      title: l10n.forgotPasswordTitle,
      subtitle: l10n.forgotPasswordSubtitle,
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFormField(
              controller: _email,
              label: l10n.fieldEmail,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (!value.contains('@') || !value.contains('.')) {
                  return l10n.errorInvalidEmail;
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 22),
            BusyFilledButton(
              busy: _submitting,
              label: l10n.actionSendCode,
              onPressed: _submit,
            ),
          ],
        ),
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l10n.rememberedPassword),
          TextButton(
            onPressed: _submitting ? null : () => context.go('/login'),
            child: Text(l10n.actionLogIn),
          ),
        ],
      ),
    );
  }
}
