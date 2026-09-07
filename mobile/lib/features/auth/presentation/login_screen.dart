import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_form_field.dart';
import 'auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _submitting = true;
      _error = null;
    });
    await ref
        .read(authControllerProvider.notifier)
        .login(email: _email.text.trim(), password: _password.text);
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    setState(() {
      _submitting = false;
      _error = state.hasError
          ? (state.error is ApiException
              ? (state.error as ApiException).message
              : l10n.errorLoginFailed)
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AuthScaffold(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
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
              validator: (v) {
                final value = v?.trim() ?? '';
                if (!value.contains('@') || !value.contains('.')) {
                  return l10n.errorInvalidEmail;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthFormField(
              controller: _password,
              label: l10n.fieldPassword,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v ?? '').length < 8 ? l10n.errorPasswordTooShort : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.actionLogIn),
            ),
          ],
        ),
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l10n.loginNewToHiww),
          TextButton(
            onPressed: _submitting ? null : () => context.go('/register'),
            child: Text(l10n.actionCreateAccount),
          ),
        ],
      ),
    );
  }
}
