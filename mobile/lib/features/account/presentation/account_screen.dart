import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/world_countries.dart';
import '../../../theme/app_colors.dart';
import '../../../ui/country_picker_field.dart';
import '../../../ui/image_picker_field.dart';
import '../../../ui/initials_avatar.dart';
import '../../../ui/section_header.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/star_rating.dart';
import '../../../ui/status_pill.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../data/account_repository.dart';

void _showEditProfile(BuildContext context, WidgetRef ref, AuthUser user) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _EditProfileSheet(user: user),
    ),
  );
}

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        leading: BackButton(onPressed: () => context.go('/browse')),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () => _showEditProfile(context, ref, user),
              child: const Text('Edit'),
            ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(
                  children: [
                    InitialsAvatar(
                      name: user.fullName,
                      url: user.avatarUrl,
                      radius: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.homeCity == null
                                ? user.email
                                : '${user.homeCity} · ${user.email}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 6),
                          StarRatingDisplay(
                            rating: user.ratingAvg,
                            trailing: user.deliveredCount > 0
                                ? '${user.deliveredCount} delivered'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!user.hasCompleteProfile) ...[
                  const SizedBox(height: 16),
                  _IncompleteProfileCard(
                    onTap: () => _showEditProfile(context, ref, user),
                  ),
                ],
                const SizedBox(height: 16),
                _ContactDetailsCard(user: user),
                const SizedBox(height: 16),
                const _KycCard(),
                if (user.pilot?.manualMoney ?? false) ...[
                  const SizedBox(height: 12),
                  _PilotCard(instructions: user.pilot!.paymentInstructions),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ],
            ),
    );
  }
}

class _IncompleteProfileCard extends StatelessWidget {
  const _IncompleteProfileCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: context.hiww.infoSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Complete your profile',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Add your phone number and delivery address — you'll need them "
            'before you can accept or make your first offer.',
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onTap, child: const Text('Add details')),
        ],
      ),
    );
  }
}

class _ContactDetailsCard extends StatelessWidget {
  const _ContactDetailsCard({required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final addressParts = [
      user.addressStreet,
      user.addressCity,
      user.addressPostalCode,
      worldCountryName(user.addressCountry),
    ].where((p) => (p ?? '').trim().isNotEmpty).join(', ');

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Contact & delivery'),
          _ContactRow(
            icon: Icons.phone_outlined,
            label: (user.phone ?? '').trim().isEmpty ? 'Add a phone number' : user.phone!,
          ),
          const SizedBox(height: 8),
          _ContactRow(
            icon: Icons.location_on_outlined,
            label: addressParts.isEmpty ? 'Add a delivery address' : addressParts,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});
  final AuthUser user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _city = TextEditingController(text: widget.user.homeCity ?? '');
  late final _phone = TextEditingController(text: widget.user.phone ?? '');
  late final _addressStreet = TextEditingController(text: widget.user.addressStreet ?? '');
  late final _addressCity = TextEditingController(text: widget.user.addressCity ?? '');
  late final _addressPostalCode =
      TextEditingController(text: widget.user.addressPostalCode ?? '');
  late String? _addressCountry = widget.user.addressCountry;
  late String? _avatarUrl = widget.user.avatarUrl;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _phone.dispose();
    _addressStreet.dispose();
    _addressCity.dispose();
    _addressPostalCode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter your name');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountRepositoryProvider)
          .updateProfile(
            fullName: _name.text.trim(),
            homeCity: _city.text.trim(),
            avatarUrl: _avatarUrl ?? '',
            phone: _phone.text.trim(),
            addressStreet: _addressStreet.text.trim(),
            addressCity: _addressCity.text.trim(),
            addressPostalCode: _addressPostalCode.text.trim(),
            addressCountry: _addressCountry ?? '',
          );
      await ref.read(authControllerProvider.notifier).refreshMe();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ImagePickerField(
                value: _avatarUrl,
                onChanged: (url) => setState(() => _avatarUrl = url),
                label: 'Profile photo',
                circle: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _city,
                decoration: const InputDecoration(
                  labelText: 'Home city (optional)',
                  hintText: 'Bangkok',
                ),
              ),
              const Divider(height: 24),
              Text('Contact & delivery', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                "Required before your first order. Only visible to Hiww and the "
                "other person on an order — never shown publicly.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+66 81 234 5678',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressStreet,
                decoration: const InputDecoration(labelText: 'Street address'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _addressCity,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _addressPostalCode,
                      decoration: const InputDecoration(labelText: 'Postal code'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CountryPickerField(
                value: _addressCountry,
                onChanged: (v) => setState(() => _addressCountry = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PilotCard extends StatelessWidget {
  const _PilotCard({required this.instructions});
  final String instructions;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: context.hiww.infoSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              Text(
                'Manual-money pilot',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Card payments are off during the pilot. You pay by bank transfer and '
            'the Hiww team confirms once the money lands.',
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              instructions,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _KycCard extends ConsumerStatefulWidget {
  const _KycCard();

  @override
  ConsumerState<_KycCard> createState() => _KycCardState();
}

class _KycCardState extends ConsumerState<_KycCard> {
  final _docId = TextEditingController();
  String _docType = 'passport';
  bool _expanded = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _docId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_docId.text.trim().length < 3) {
      setState(() => _error = 'Enter your document number');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(accountRepositoryProvider)
          .submitKyc(documentType: _docType, documentId: _docId.text.trim());
      await ref.read(authControllerProvider.notifier).refreshMe();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _expanded = false;
        _docId.clear();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Submitted for review')));
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
    final user = ref.watch(currentUserProvider)!;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionHeader('ID check')),
              StatusPill(user.kycStatus),
            ],
          ),
          Text(
            user.isKycApproved
                ? 'Your identity has been verified.'
                : 'Verify your identity before completing an order. The Hiww '
                      'team reviews submissions manually during the pilot.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (!user.isKycApproved) ...[
            const SizedBox(height: 12),
            if (!_expanded)
              FilledButton.tonal(
                onPressed: () => setState(() => _expanded = true),
                child: Text(
                  user.kycStatus == 'pending'
                      ? 'Update ID details'
                      : 'Submit ID details',
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _docType,
                decoration: const InputDecoration(labelText: 'Document type'),
                items: const [
                  DropdownMenuItem(value: 'passport', child: Text('Passport')),
                  DropdownMenuItem(
                    value: 'id_card',
                    child: Text('National ID card'),
                  ),
                  DropdownMenuItem(
                    value: 'drivers_license',
                    child: Text("Driver's licence"),
                  ),
                ],
                onChanged: (v) => setState(() => _docType = v ?? 'passport'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _docId,
                decoration: const InputDecoration(labelText: 'Document number'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit for review'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
