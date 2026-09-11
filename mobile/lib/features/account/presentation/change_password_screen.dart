import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/password_policy.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/busy_filled_button.dart';
import '../../../ui/password_requirements_info.dart';
import '../../../ui/password_strength_bar.dart';
import '../../auth/application/auth_controller.dart';

/// A single-purpose screen for changing the password — reached from the
/// locked "Password" row on Personal Information, same shape as phone/email's
/// Change flow. Unlike those, a password change doesn't invalidate an OTP
/// verification, so this just needs the current password (to prove it's
/// really the account owner) plus a new one, twice.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_currentPassword.text.isEmpty) {
      setState(() => _error = l10n.errorEnterCurrentPassword);
      return;
    }
    final policyError = validateNewPassword(_newPassword.text, l10n);
    if (policyError != null) {
      setState(() => _error = policyError);
      return;
    }
    if (_confirmPassword.text != _newPassword.text) {
      setState(() => _error = l10n.errorPasswordsDontMatch);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: _currentPassword.text,
            newPassword: _newPassword.text,
          );
      if (!mounted) return;
      // Pop first — a SnackBar shown on this screen's own Scaffold would be
      // torn down with it if queued right before the pop, same reasoning
      // ChangeContactScreen's success path already follows.
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.actionChangePassword)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _currentPassword,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.fieldCurrentPassword),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPassword,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.fieldNewPassword,
                  suffixIcon: const PasswordRequirementsInfo(),
                ),
              ),
              PasswordStrengthBar(password: _newPassword.text),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPassword,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.fieldConfirmPassword),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              BusyFilledButton(
                busy: _submitting,
                label: l10n.actionSave,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
