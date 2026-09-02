import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../application/auth_controller.dart';
import '../domain/auth_user.dart';
import 'auth_form_field.dart';
import 'auth_scaffold.dart';

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
  UserType _userType = UserType.both;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    await ref.read(authControllerProvider.notifier).register(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          userType: _userType,
        );
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    setState(() {
      _submitting = false;
      _error = state.hasError ? _messageFor(state.error) : null;
    });
  }

  String _messageFor(Object? error) {
    if (error is ApiException) {
      if (error.code == 'USER_EXISTS') {
        return 'An account with that email already exists.';
      }
      return error.message;
    }
    return 'Could not create your account. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Shop from travelers, or earn on trips you already take.',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFormField(
              controller: _name,
              label: 'Full name',
              autofillHints: const [AutofillHints.name],
              validator: (v) =>
                  (v?.trim() ?? '').length < 2 ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 14),
            AuthFormField(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (v) {
                final value = v?.trim() ?? '';
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthFormField(
              controller: _password,
              label: 'Password',
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) =>
                  (v ?? '').length < 8 ? 'At least 8 characters' : null,
            ),
            const SizedBox(height: 16),
            Text('I want to…',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<UserType>(
              segments: const [
                ButtonSegment(value: UserType.shopper, label: Text('Shop')),
                ButtonSegment(value: UserType.traveler, label: Text('Travel')),
                ButtonSegment(value: UserType.both, label: Text('Both')),
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
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Already have an account?'),
          TextButton(
            onPressed: _submitting ? null : () => context.go('/login'),
            child: const Text('Log in'),
          ),
        ],
      ),
    );
  }
}
