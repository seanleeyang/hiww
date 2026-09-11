import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/busy_filled_button.dart';
import '../../../ui/phone_field.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../data/account_repository.dart';

enum ContactChannel { phone, email }

/// A single-purpose screen for changing just the phone number or just the
/// email address — deliberately separate from the bulk "Edit profile" form
/// (whose Save button used to bundle a phone/email change in with unrelated
/// fields like name/address, so saving anything else could silently kick
/// off a re-verification gate the user wasn't expecting). Submitting here
/// goes straight to /verify if the change actually invalidated the channel
/// — no intermediate snackbar detour, since that's the entire point of this
/// screen.
class ChangeContactScreen extends ConsumerStatefulWidget {
  const ChangeContactScreen({super.key, required this.channel});
  final ContactChannel channel;

  @override
  ConsumerState<ChangeContactScreen> createState() => _ChangeContactScreenState();
}

class _ChangeContactScreenState extends ConsumerState<ChangeContactScreen> {
  final _email = TextEditingController();
  String _phone = '';
  bool _submitting = false;
  String? _error;
  bool _initialized = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthUser user) async {
    final l10n = AppLocalizations.of(context)!;
    final isPhone = widget.channel == ContactChannel.phone;

    if (isPhone) {
      if (_phone.trim().isEmpty) {
        setState(() => _error = l10n.errorEnterNewPhone);
        return;
      }
    } else {
      final value = _email.text.trim();
      if (!value.contains('@') || !value.contains('.')) {
        setState(() => _error = l10n.errorInvalidEmail);
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final wasVerified = isPhone ? user.phoneVerified : user.emailVerified;
    try {
      await ref.read(accountRepositoryProvider).updateProfile(
            phone: isPhone ? _phone.trim() : null,
            email: isPhone ? null : _email.text.trim(),
          );
      await ref.read(authControllerProvider.notifier).refreshMe();
      if (!mounted) return;
      final updated = ref.read(currentUserProvider);
      final nowVerified = isPhone ? updated?.phoneVerified : updated?.emailVerified;
      final needsVerification = wasVerified && !(nowVerified ?? true);
      if (needsVerification) {
        context.go('/verify');
      } else {
        // Resubmitted the same value — nothing actually changed, just go back.
        context.pop();
      }
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
    final user = ref.watch(currentUserProvider);
    final isPhone = widget.channel == ContactChannel.phone;

    if (user != null && !_initialized) {
      _initialized = true;
      if (isPhone) {
        _phone = user.phone ?? '';
      } else {
        _email.text = user.email;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isPhone ? l10n.changePhoneTitle : l10n.changeEmailTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.changeContactNote,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              if (isPhone)
                PhoneField(
                  value: _phone,
                  onChanged: (v) => _phone = v,
                )
              else
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l10n.fieldNewEmail),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              if (user != null)
                BusyFilledButton(
                  busy: _submitting,
                  label: l10n.actionSave,
                  onPressed: () => _submit(user),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
