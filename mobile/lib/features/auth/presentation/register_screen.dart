import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/phone_field.dart';
import '../application/auth_controller.dart';
import '../domain/auth_user.dart';
import 'auth_form_field.dart';
import 'auth_scaffold.dart';
import 'social_auth_buttons.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  String _phone = '';
  UserType _userType = UserType.both;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    if (_phone.trim().isEmpty) {
      setState(() => _error = l10n.errorEnterPhone);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    await ref.read(authControllerProvider.notifier).register(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          userType: _userType,
          phone: _phone.trim(),
        );
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    setState(() {
      _submitting = false;
      _error = state.hasError ? _messageFor(state.error, l10n) : null;
    });
  }

  String _messageFor(Object? error, AppLocalizations l10n) {
    if (error is ApiException) {
      if (error.code == 'USER_EXISTS') {
        return l10n.errorUserExists;
      }
      return error.message;
    }
    return l10n.errorRegisterFailed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AuthScaffold(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SocialAuthButtons(),
            const SocialAuthDivider(),
            AuthFormField(
              controller: _name,
              label: l10n.fieldFullName,
              autofillHints: const [AutofillHints.name],
              validator: (v) =>
                  (v?.trim() ?? '').length < 2 ? l10n.errorEnterFullName : null,
            ),
            const SizedBox(height: 14),
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
            PhoneField(value: _phone, onChanged: (v) => _phone = v),
            const SizedBox(height: 14),
            AuthFormField(
              controller: _password,
              label: l10n.fieldPassword,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) =>
                  (v ?? '').length < 8 ? l10n.errorPasswordTooShort : null,
            ),
            const SizedBox(height: 14),
            AuthFormField(
              controller: _confirmPassword,
              label: l10n.fieldConfirmPassword,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) =>
                  v != _password.text ? l10n.errorPasswordsDontMatch : null,
            ),
            const SizedBox(height: 16),
            Text(l10n.registerIWantTo,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<UserType>(
              segments: [
                ButtonSegment(value: UserType.shopper, label: Text(l10n.userTypeShop)),
                ButtonSegment(value: UserType.traveler, label: Text(l10n.userTypeTravel)),
                ButtonSegment(value: UserType.both, label: Text(l10n.userTypeBoth)),
              ],
              selected: {_userType},
              onSelectionChanged: (s) => setState(() => _userType = s.first),
              showSelectedIcon: false,
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
                  : Text(l10n.actionCreateAccountButton),
            ),
          ],
        ),
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l10n.registerAlreadyHaveAccount),
          TextButton(
            onPressed: _submitting ? null : () => context.go('/login'),
            child: Text(l10n.actionLogIn),
          ),
        ],
      ),
    );
  }
}
