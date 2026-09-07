import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/world_countries.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../ui/country_picker_field.dart';
import '../../../ui/image_picker_field.dart';
import '../../../ui/initials_avatar.dart';
import '../../../ui/phone_field.dart';
import '../../../ui/section_header.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/star_rating.dart';
import '../../../ui/status_pill.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../../settings/locale_controller.dart';
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountTitle),
        leading: BackButton(onPressed: () => context.go('/browse')),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () => _showEditProfile(context, ref, user),
              child: Text(l10n.actionEdit),
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
                _ContactDetailsCard(user: user),
                const SizedBox(height: 16),
                const _KycCard(),
                if (user.pilot?.manualMoney ?? false) ...[
                  const SizedBox(height: 12),
                  _PilotCard(instructions: user.pilot!.paymentInstructions),
                ],
                const SizedBox(height: 16),
                const _LanguageCard(),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.actionLogOut),
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

/// English/Thai switcher. `null` selection means "follow the system locale",
/// but once someone picks one explicitly it's persisted via
/// [localeControllerProvider] and used regardless of device language.
class _LanguageCard extends ConsumerWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final chosen = ref.watch(localeControllerProvider).valueOrNull;
    final current = chosen?.languageCode ?? Localizations.localeOf(context).languageCode;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(l10n.settingsLanguage),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
              ButtonSegment(value: 'th', label: Text(l10n.languageThai)),
            ],
            selected: {current == 'th' ? 'th' : 'en'},
            onSelectionChanged: (s) =>
                ref.read(localeControllerProvider.notifier).setLocale(Locale(s.first)),
            showSelectedIcon: false,
          ),
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
    final l10n = AppLocalizations.of(context)!;
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
          SectionHeader(l10n.sectionContactDelivery),
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
  late String _phone = widget.user.phone ?? '';
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
    _addressStreet.dispose();
    _addressCity.dispose();
    _addressPostalCode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = AppLocalizations.of(context)!.errorEnterName);
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
            phone: _phone.trim(),
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
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.fieldFullName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _city,
                decoration: InputDecoration(
                  labelText: l10n.fieldHomeCity,
                  hintText: 'Bangkok',
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
              PhoneField(
                value: _phone,
                defaultCountryCode: _addressCountry,
                onChanged: (v) => _phone = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressStreet,
                decoration: InputDecoration(labelText: l10n.fieldStreetAddress),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _addressCity,
                      decoration: InputDecoration(labelText: l10n.fieldCity),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _addressPostalCode,
                      decoration: InputDecoration(labelText: l10n.fieldPostalCode),
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
                    : Text(l10n.actionSave),
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
      setState(() => _error = AppLocalizations.of(context)!.errorEnterDocumentNumber);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.infoSubmittedForReview)),
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
            user.isKycApproved ? l10n.kycVerified : l10n.kycUnverified,
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
                  DropdownMenuItem(
                    value: 'drivers_license',
                    child: Text(l10n.docDriversLicense),
                  ),
                ],
                onChanged: (v) => setState(() => _docType = v ?? 'passport'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _docId,
                decoration: InputDecoration(labelText: l10n.fieldDocumentNumber),
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
                    : Text(l10n.actionSubmitForReview),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
