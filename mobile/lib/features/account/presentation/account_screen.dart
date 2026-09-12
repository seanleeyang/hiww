import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/thai_banks.dart';
import '../../../core/thai_id_formatter.dart';
import '../../../core/world_countries.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../ui/country_picker_field.dart';
import '../../../ui/image_picker_field.dart';
import '../../../ui/initials_avatar.dart';
import '../../../ui/busy_filled_button.dart';
import '../../../ui/section_header.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/star_rating.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/status_pill.dart';
import '../../../ui/language_toggle.dart';
import '../../../ui/thai_address_picker.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../data/account_repository.dart';
import 'change_contact_screen.dart';

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

void _showBankAccountSheet(BuildContext context, WidgetRef ref, AuthUser user) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _BankAccountSheet(user: user),
    ),
  );
}

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the controller directly (rather than currentUserProvider,
    // which collapses "still loading" and "the fetch genuinely failed" into
    // the same null) so a real failure gets AsyncValueView's error + Retry
    // instead of a spinner with no way out.
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull is AuthSignedIn ? (authState.valueOrNull as AuthSignedIn).user : null;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountTitle),
        leading: BackButton(onPressed: () => context.go('/browse')),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: LanguageToggle(),
          ),
        ],
      ),
      body: AsyncValueView(
        value: authState,
        onRetry: () => ref.invalidate(authControllerProvider),
        data: (_) {
          // Not actually signed in — the router redirects away from
          // /account momentarily; render nothing in the meantime.
          if (user == null) return const SizedBox.shrink();
          return ListView(
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
                                ? l10n.deliveredCount(user.deliveredCount)
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
                _ContactDetailsCard(
                  user: user,
                  onEdit: () => _showEditProfile(context, ref, user),
                ),
                const SizedBox(height: 16),
                _BankAccountCard(
                  user: user,
                  onEdit: () => _showBankAccountSheet(context, ref, user),
                ),
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
                  label: Text(l10n.actionLogOut),
                ),
              ],
            );
        },
      ),
    );
  }
}

class _IncompleteProfileCard extends StatelessWidget {
  const _IncompleteProfileCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  l10n.accountCompleteProfile,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.accountCompleteProfileBody),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onTap, child: Text(l10n.actionAddDetails)),
        ],
      ),
    );
  }
}

class _ContactDetailsCard extends StatelessWidget {
  const _ContactDetailsCard({required this.user, required this.onEdit});
  final AuthUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final addressParts = [
      user.addressStreet,
      user.addressStreet2,
      user.addressSubdistrict,
      user.addressDistrict,
      user.addressCity,
      user.addressPostalCode,
      worldCountryName(user.addressCountry, l10n.localeName),
    ].where((p) => (p ?? '').trim().isNotEmpty).join(', ');

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            l10n.sectionContactDelivery,
            action: TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l10n.actionEdit),
            ),
          ),
          _ContactRow(
            icon: Icons.person_outline,
            label: _genderAndBirthdayLabel(l10n, user) ?? l10n.fieldGender,
          ),
          const SizedBox(height: 8),
          _ContactRow(
            icon: Icons.email_outlined,
            label: user.email,
          ),
          const SizedBox(height: 8),
          _ContactRow(
            icon: Icons.phone_outlined,
            label: (user.phone ?? '').trim().isEmpty ? l10n.accountAddPhone : user.phone!,
          ),
          const SizedBox(height: 8),
          _ContactRow(
            icon: Icons.location_on_outlined,
            label: addressParts.isEmpty ? l10n.accountAddAddress : addressParts,
          ),
        ],
      ),
    );
  }

  String? _genderAndBirthdayLabel(AppLocalizations l10n, AuthUser user) {
    final gender = switch (user.gender) {
      'male' => l10n.genderMale,
      'female' => l10n.genderFemale,
      'prefer_not_to_say' => l10n.genderPreferNotToSay,
      _ => null,
    };
    final parts = [gender, user.dateOfBirth].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' · ');
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

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard({required this.user, required this.onEdit});
  final AuthUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bankName = (user.bankName ?? '').trim();
    final accountNumber = (user.bankAccountNumber ?? '').trim();
    final hasBank = bankName.isNotEmpty && accountNumber.isNotEmpty;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            l10n.sectionBankAccount,
            action: TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l10n.actionEdit),
            ),
          ),
          _ContactRow(
            icon: Icons.account_balance_outlined,
            label: hasBank
                ? '${bankLabel(bankName, l10n.localeName)} · $accountNumber'
                : l10n.accountAddBankAccount,
          ),
        ],
      ),
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
  late final _firstName = TextEditingController(text: _splitName(widget.user.fullName).$1);
  late final _surname = TextEditingController(text: _splitName(widget.user.fullName).$2);
  late final _addressStreet = TextEditingController(text: widget.user.addressStreet ?? '');
  late final _addressStreet2 = TextEditingController(text: widget.user.addressStreet2 ?? '');
  late final _addressCity = TextEditingController(text: widget.user.addressCity ?? '');
  late final _addressDistrict = TextEditingController(text: widget.user.addressDistrict ?? '');
  late final _addressSubdistrict =
      TextEditingController(text: widget.user.addressSubdistrict ?? '');
  late final _addressPostalCode =
      TextEditingController(text: widget.user.addressPostalCode ?? '');
  late String? _addressCountry = widget.user.addressCountry;
  late String? _avatarUrl = widget.user.avatarUrl;
  late String? _gender = widget.user.gender;
  late DateTime? _dateOfBirth =
      widget.user.dateOfBirth == null ? null : DateTime.tryParse(widget.user.dateOfBirth!);
  bool _busy = false;
  String? _error;

  static (String, String) _splitName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return ('', '');
    return (parts.first, parts.length > 1 ? parts.sublist(1).join(' ') : '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _surname.dispose();
    _addressStreet.dispose();
    _addressStreet2.dispose();
    _addressCity.dispose();
    _addressDistrict.dispose();
    _addressSubdistrict.dispose();
    _addressPostalCode.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: maxDate,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  // Closes this sheet, then pushes the dedicated single-purpose screen for
  // changing phone/email — kept entirely separate from Save below so
  // changing an unrelated field (name, address, …) can never silently kick
  // off a re-verification gate the user didn't ask for.
  void _goToChange(ContactChannel channel) {
    Navigator.of(context).pop();
    context.push(
      channel == ContactChannel.phone ? '/account/change-phone' : '/account/change-email',
    );
  }

  void _goToChangePassword() {
    Navigator.of(context).pop();
    context.push('/account/change-password');
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_firstName.text.trim().isEmpty) {
      setState(() => _error = l10n.errorEnterFirstName);
      return;
    }
    if (_surname.text.trim().isEmpty) {
      setState(() => _error = l10n.errorEnterSurname);
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
            fullName: '${_firstName.text.trim()} ${_surname.text.trim()}',
            avatarUrl: _avatarUrl ?? '',
            gender: _gender ?? '',
            dateOfBirth: _dateOfBirth == null ? '' : _isoDate(_dateOfBirth!),
            addressStreet: _addressStreet.text.trim(),
            addressStreet2: _addressStreet2.text.trim(),
            addressDistrict: _addressDistrict.text.trim(),
            addressSubdistrict: _addressSubdistrict.text.trim(),
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

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.editProfileTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ImagePickerField(
                value: _avatarUrl,
                onChanged: (url) => setState(() => _avatarUrl = url),
                label: l10n.fieldProfilePhoto,
                circle: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: l10n.fieldFirstName),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _surname,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: l10n.fieldSurname),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: InputDecoration(labelText: l10n.fieldGender),
                items: [
                  DropdownMenuItem(value: 'male', child: Text(l10n.genderMale)),
                  DropdownMenuItem(value: 'female', child: Text(l10n.genderFemale)),
                  DropdownMenuItem(
                    value: 'prefer_not_to_say',
                    child: Text(l10n.genderPreferNotToSay),
                  ),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickBirthday,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.fieldBirthday,
                    suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(_dateOfBirth == null ? '—' : _isoDate(_dateOfBirth!)),
                ),
              ),
              const Divider(height: 24),
              Text(l10n.sectionContactDelivery, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                l10n.contactDeliveryNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _LockedContactRow(
                label: l10n.fieldEmail,
                value: widget.user.email,
                onChange: () => _goToChange(ContactChannel.email),
              ),
              const SizedBox(height: 12),
              _LockedContactRow(
                label: l10n.labelPhone,
                value: widget.user.phone ?? '',
                onChange: () => _goToChange(ContactChannel.phone),
              ),
              const SizedBox(height: 12),
              _LockedContactRow(
                label: l10n.fieldPassword,
                value: '••••••••',
                onChange: _goToChangePassword,
              ),
              const SizedBox(height: 12),
              CountryPickerField(
                value: _addressCountry,
                onChanged: (v) => setState(() => _addressCountry = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressStreet,
                decoration: InputDecoration(labelText: l10n.fieldStreetAddress),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressStreet2,
                decoration: InputDecoration(labelText: l10n.fieldStreetAddress2),
              ),
              const SizedBox(height: 12),
              if (_addressCountry == 'TH')
                ThaiAddressPicker(
                  province: _addressCity.text,
                  district: _addressDistrict.text,
                  subdistrict: _addressSubdistrict.text,
                  postalCode: _addressPostalCode.text,
                  provinceLabel: l10n.fieldProvince,
                  districtLabel: l10n.fieldDistrict,
                  subdistrictLabel: l10n.fieldSubdistrict,
                  postalCodeLabel: l10n.fieldPostalCode,
                  onChanged: ({
                    required province,
                    required district,
                    required subdistrict,
                    required postalCode,
                  }) {
                    setState(() {
                      _addressCity.text = province;
                      _addressDistrict.text = district;
                      _addressSubdistrict.text = subdistrict;
                      _addressPostalCode.text = postalCode;
                    });
                  },
                )
              else ...[
                TextField(
                  controller: _addressCity,
                  decoration: InputDecoration(
                    labelText: usesProvinceLabel(_addressCountry) ? l10n.fieldProvince : l10n.fieldCity,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressDistrict,
                  decoration: InputDecoration(labelText: l10n.fieldDistrict),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressSubdistrict,
                  decoration: InputDecoration(labelText: l10n.fieldSubdistrict),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressPostalCode,
                  decoration: InputDecoration(labelText: l10n.fieldPostalCode),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              BusyFilledButton(
                busy: _busy,
                label: l10n.actionSave,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A read-only field paired with a "Change" button, for phone/email — these
/// can't be edited inline here since changing either invalidates its
/// verification; [onChange] hands off to the dedicated screen that handles
/// that properly (see [ChangeContactScreen]).
class _LockedContactRow extends StatelessWidget {
  const _LockedContactRow({required this.label, required this.value, required this.onChange});
  final String label;
  final String value;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(labelText: label),
            child: Text(
              value.isEmpty ? '—' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: onChange, child: Text(l10n.actionChange)),
      ],
    );
  }
}

class _BankAccountSheet extends ConsumerStatefulWidget {
  const _BankAccountSheet({required this.user});
  final AuthUser user;

  @override
  ConsumerState<_BankAccountSheet> createState() => _BankAccountSheetState();
}

class _BankAccountSheetState extends ConsumerState<_BankAccountSheet> {
  late String? _bankName = widget.user.bankName;
  late final _accountNumber = TextEditingController(text: widget.user.bankAccountNumber ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _accountNumber.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if ((_bankName ?? '').trim().isEmpty) {
      setState(() => _error = l10n.errorSelectBank);
      return;
    }
    if (_accountNumber.text.trim().isEmpty) {
      setState(() => _error = l10n.errorEnterBankAccountNumber);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).updateProfile(
            bankName: _bankName,
            bankAccountNumber: _accountNumber.text.trim(),
          );
      await ref.read(authControllerProvider.notifier).refreshMe();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.infoBankAccountUpdated)),
      );
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
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.bankAccountTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l10n.bankAccountNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue:
                    kThaiBanks.any((b) => b.value == _bankName) ? _bankName : null,
                decoration: InputDecoration(labelText: l10n.fieldBank),
                items: kThaiBanks
                    .map((bank) => DropdownMenuItem(
                          value: bank.value,
                          child: Text(bankLabel(bank.value, l10n.localeName)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _bankName = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountNumber,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l10n.fieldBankAccountNumber),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              BusyFilledButton(
                busy: _busy,
                label: l10n.actionSubmit,
                onPressed: _submit,
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
    final l10n = AppLocalizations.of(context)!;
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
                l10n.pilotTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.pilotBody),
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
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  // Passport addresses aren't in any standard machine-readable shape, so
  // they stay one free-text field. A Thai ID card / house-registration
  // address, though, always has the same components (house/plot no., Moo,
  // Soi, Road, sub-district, district, province, postal code) — see
  // `_houseNumber` etc. below — so it's collected as those instead and
  // composed into one string for the backend's single `address` column.
  final _address = TextEditingController();
  final _houseNumber = TextEditingController();
  final _villageNumber = TextEditingController();
  final _alley = TextEditingController();
  final _road = TextEditingController();
  final _addrProvince = TextEditingController();
  final _addrDistrict = TextEditingController();
  final _addrSubdistrict = TextEditingController();
  final _addrPostalCode = TextEditingController();
  String _docType = 'id_card';
  String? _photoUrl;
  String? _selfieUrl;
  bool _expanded = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _docId.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _address.dispose();
    _houseNumber.dispose();
    _villageNumber.dispose();
    _alley.dispose();
    _road.dispose();
    _addrProvince.dispose();
    _addrDistrict.dispose();
    _addrSubdistrict.dispose();
    _addrPostalCode.dispose();
    super.dispose();
  }

  /// Assembles the Thai ID address fields into one string, in the standard
  /// house-registration order, for the backend's single `kyc_address`
  /// column — e.g. "123/45 Moo 6, Soi Sukhumvit 24, Sukhumvit Road,
  /// Khlong Tan Nuea, Watthana, Bangkok 10110".
  String _composedThaiAddress() {
    final parts = <String>[];
    if (_houseNumber.text.trim().isNotEmpty) parts.add(_houseNumber.text.trim());
    if (_villageNumber.text.trim().isNotEmpty) parts.add('Moo ${_villageNumber.text.trim()}');
    if (_alley.text.trim().isNotEmpty) parts.add('Soi ${_alley.text.trim()}');
    if (_road.text.trim().isNotEmpty) parts.add('${_road.text.trim()} Road');
    final line1 = parts.join(', ');

    final locality = [_addrSubdistrict.text, _addrDistrict.text, _addrProvince.text]
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(', ');

    return [line1, [locality, _addrPostalCode.text.trim()].where((p) => p.isNotEmpty).join(' ')]
        .where((p) => p.isNotEmpty)
        .join(', ');
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      setState(() => _error = l10n.errorEnterNameOnDocument);
      return;
    }
    if (_docType == 'id_card') {
      if (_docId.text.replaceAll(RegExp(r'\D'), '').length != 13) {
        setState(() => _error = l10n.errorEnterValidThaiId);
        return;
      }
    } else if (_docId.text.trim().length < 3) {
      setState(() => _error = l10n.errorEnterDocumentNumber);
      return;
    }
    if (_docType == 'id_card') {
      if (_houseNumber.text.trim().isEmpty ||
          _addrProvince.text.trim().isEmpty ||
          _addrDistrict.text.trim().isEmpty ||
          _addrSubdistrict.text.trim().isEmpty ||
          _addrPostalCode.text.trim().isEmpty) {
        setState(() => _error = l10n.errorEnterAddressOnDocument);
        return;
      }
    } else if (_address.text.trim().length < 3) {
      setState(() => _error = l10n.errorEnterAddressOnDocument);
      return;
    }
    if (_photoUrl == null) {
      setState(() => _error = l10n.errorDocumentPhotoRequired);
      return;
    }
    if (_selfieUrl == null) {
      setState(() => _error = l10n.errorSelfiePhotoRequired);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).submitKyc(
            documentType: _docType,
            documentId: _docId.text.trim(),
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            address: _docType == 'id_card' ? _composedThaiAddress() : _address.text.trim(),
            documentPhotoUrl: _photoUrl!,
            selfiePhotoUrl: _selfieUrl!,
          );
      await ref.read(authControllerProvider.notifier).refreshMe();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _expanded = false;
        _docId.clear();
        _firstName.clear();
        _lastName.clear();
        _address.clear();
        _houseNumber.clear();
        _villageNumber.clear();
        _alley.clear();
        _road.clear();
        _addrProvince.clear();
        _addrDistrict.clear();
        _addrSubdistrict.clear();
        _addrPostalCode.clear();
        _photoUrl = null;
        _selfieUrl = null;
      });
      await showDialog<void>(
        context: context,
        builder: (_) => _KycSubmittedDialog(l10n: l10n),
      );
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
    final l10n = AppLocalizations.of(context)!;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionHeader(l10n.kycSectionTitle)),
              StatusPill(user.kycStatus),
            ],
          ),
          Text(
            user.isKycApproved
                ? l10n.kycVerified
                : user.isKycAwaitingReview
                    ? l10n.kycUnderReview
                    : l10n.kycUnverified,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          // Locked while approved (forever) or while a submission is
          // awaiting review (until an admin approves or rejects it) — see
          // AuthUser.isKycAwaitingReview. This is what stops a user from
          // resubmitting (and re-triggering the paid AI check) again and
          // again while still waiting on a review.
          if (!user.isKycApproved && !user.isKycAwaitingReview) ...[
            const SizedBox(height: 12),
            if (!_expanded)
              FilledButton.tonal(
                onPressed: () => setState(() {
                  _expanded = true;
                  if (_firstName.text.isEmpty && _lastName.text.isEmpty) {
                    final parts = user.fullName.trim().split(RegExp(r'\s+'));
                    _firstName.text = parts.first;
                    if (parts.length > 1) _lastName.text = parts.sublist(1).join(' ');
                  }
                }),
                child: Text(
                  user.kycStatus == 'rejected'
                      ? l10n.actionUpdateIdDetails
                      : l10n.actionSubmitIdDetails,
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _docType,
                decoration: InputDecoration(labelText: l10n.fieldDocumentType),
                items: [
                  DropdownMenuItem(value: 'passport', child: Text(l10n.docPassport)),
                  DropdownMenuItem(
                    value: 'id_card',
                    child: Text(l10n.docIdCard),
                  ),
                ],
                onChanged: (v) => setState(() {
                  final wasIdCard = _docType == 'id_card';
                  _docType = v ?? 'id_card';
                  final nowIdCard = _docType == 'id_card';
                  if (nowIdCard && !wasIdCard) {
                    _docId.text = formatThaiNationalId(_docId.text);
                  } else if (!nowIdCard && wasIdCard) {
                    _docId.text = _docId.text.replaceAll('-', '');
                  }
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstName,
                      decoration: InputDecoration(labelText: l10n.fieldFirstNameOnDocument),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lastName,
                      decoration: InputDecoration(labelText: l10n.fieldLastNameOnDocument),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _docId,
                decoration: InputDecoration(
                  labelText: l10n.fieldDocumentNumber,
                  hintText: _docType == 'id_card' ? '1-2345-67890-12-3' : null,
                ),
                keyboardType: _docType == 'id_card' ? TextInputType.number : TextInputType.text,
                inputFormatters:
                    _docType == 'id_card' ? [ThaiNationalIdInputFormatter()] : null,
              ),
              const SizedBox(height: 12),
              if (_docType == 'id_card') ...[
                TextField(
                  controller: _houseNumber,
                  decoration: InputDecoration(
                    labelText: l10n.fieldHouseNumber,
                    hintText: '123/45',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _villageNumber,
                        decoration: InputDecoration(labelText: l10n.fieldVillageNumber),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _alley,
                        decoration: InputDecoration(labelText: l10n.fieldAlley),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _road,
                  decoration: InputDecoration(labelText: l10n.fieldRoad),
                ),
                const SizedBox(height: 12),
                ThaiAddressPicker(
                  province: _addrProvince.text,
                  district: _addrDistrict.text,
                  subdistrict: _addrSubdistrict.text,
                  postalCode: _addrPostalCode.text,
                  provinceLabel: l10n.fieldProvince,
                  districtLabel: l10n.fieldDistrict,
                  subdistrictLabel: l10n.fieldSubdistrict,
                  postalCodeLabel: l10n.fieldPostalCode,
                  onChanged: ({
                    required province,
                    required district,
                    required subdistrict,
                    required postalCode,
                  }) {
                    setState(() {
                      _addrProvince.text = province;
                      _addrDistrict.text = district;
                      _addrSubdistrict.text = subdistrict;
                      _addrPostalCode.text = postalCode;
                    });
                  },
                ),
              ] else
                TextField(
                  controller: _address,
                  decoration: InputDecoration(labelText: l10n.fieldAddressOnDocument),
                  maxLines: 2,
                ),
              const SizedBox(height: 12),
              ImagePickerField(
                value: _photoUrl,
                onChanged: (url) => setState(() => _photoUrl = url),
                label: l10n.fieldDocumentPhoto,
              ),
              const SizedBox(height: 12),
              ImagePickerField(
                value: _selfieUrl,
                onChanged: (url) => setState(() => _selfieUrl = url),
                label: l10n.fieldSelfieWithDocument,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              BusyFilledButton(
                busy: _submitting,
                label: l10n.actionSubmitForReview,
                onPressed: _submit,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Shown once a KYC submission goes through, alongside the `kyc_submitted`
/// notification recorded server-side — this is the immediate, in-the-moment
/// confirmation; the notification is there for whenever the user next opens
/// the inbox. Closed only by its explicit X, never a tap-outside dismiss, so
/// it isn't missed.
class _KycSubmittedDialog extends StatelessWidget {
  const _KycSubmittedDialog({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.kycSubmittedDialogTitle)),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.actionClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
      content: Text(l10n.kycSubmittedDialogBody),
    );
  }
}

