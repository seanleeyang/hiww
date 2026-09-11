import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/password_policy.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/busy_filled_button.dart';
import '../../../ui/password_requirements_info.dart';
import '../../../ui/password_strength_bar.dart';
import '../application/auth_controller.dart';
import 'auth_form_field.dart';
import 'auth_scaffold.dart';

/// Second step of the forgot-password flow: enter the code that was sent to
/// [email], plus a new password. On success the backend signs the user
/// straight in with a fresh token (mirrors what register does after OTP
/// verification), so there's no separate "now go log in" step.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.email, this.devCode});

  final String email;
  final String? devCode;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.devCode != null) _code.text = widget.devCode!;
  }

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
            email: widget.email,
            code: _code.text.trim(),
            newPassword: _password.text,
          );
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
      title: l10n.resetPasswordTitle,
      subtitle: l10n.resetPasswordSubtitle(widget.email),
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.devCode != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.devCodeNotice(widget.devCode!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            AuthFormField(
              controller: _code,
              label: l10n.fieldOtpCode,
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (v?.trim() ?? '').length != 6 ? l10n.errorEnterOtpCode : null,
            ),
            const SizedBox(height: 14),
            AuthFormField(
              controller: _password,
              label: l10n.fieldNewPassword,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              suffixIcon: const PasswordRequirementsInfo(),
              onChanged: (_) => setState(() {}),
              validator: (v) => validateNewPassword(v, l10n),
            ),
            PasswordStrengthBar(password: _password.text),
            const SizedBox(height: 14),
            AuthFormField(
              controller: _confirmPassword,
              label: l10n.fieldConfirmPassword,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  v != _password.text ? l10n.errorPasswordsDontMatch : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 22),
            BusyFilledButton(
              busy: _submitting,
              label: l10n.actionResetPassword,
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
