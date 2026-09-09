import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/countries.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/image_picker_field.dart';
import '../../discovery/data/discovery_repository.dart';
import '../data/trips_repository.dart';

/// Posting a new trip is a near-full-height bottom sheet, matching the
/// Create Order flow's presentation. Editing an existing trip is a separate,
/// simpler full-screen flow — see `new_trip_screen.dart`'s `EditTripScreen`.
Future<void> showAddTripSheet(
  BuildContext context, {
  String? fromCountry,
  String? fromCity,
  String? toCountry,
  String? toCity,
  DateTime? depart,
  DateTime? ret,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddTripSheet(
      fromCountry: fromCountry,
      fromCity: fromCity,
      toCountry: toCountry,
      toCity: toCity,
      depart: depart,
      ret: ret,
    ),
  );
}

class _AddTripSheet extends ConsumerStatefulWidget {
  const _AddTripSheet({
    this.fromCountry,
    this.fromCity,
    this.toCountry,
    this.toCity,
    this.depart,
    this.ret,
  });

  final String? fromCountry;
  final String? fromCity;
  final String? toCountry;
  final String? toCity;
  final DateTime? depart;
  final DateTime? ret;

  @override
  ConsumerState<_AddTripSheet> createState() => _AddTripSheetState();
}

class _AddTripSheetState extends ConsumerState<_AddTripSheet> {
  late final _fromCity = TextEditingController(text: widget.fromCity ?? '');
  late final _toCity = TextEditingController(text: widget.toCity ?? '');
  final _note = TextEditingController();
  final _weight = TextEditingController(text: '8');
  final _items = TextEditingController(text: '5');
  late String _from = widget.fromCountry ?? 'TH';
  late String _to = widget.toCountry ?? 'JP';
  String? _coverUrl;
  late DateTime? _depart = widget.depart;
  late DateTime? _ret = widget.ret;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _fromCity.dispose();
    _toCity.dispose();
    _note.dispose();
    _weight.dispose();
    _items.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final weight = double.tryParse(_weight.text.trim());
    final items = int.tryParse(_items.text.trim());
    if (_depart == null || _ret == null) {
      setState(() => _error = l10n.errorPickTravelDates);
      return;
    }
    if (weight == null || weight <= 0 || items == null || items <= 0) {
      setState(() => _error = l10n.errorEnterWeightAndItems);
      return;
    }
    if (!_ret!.isAfter(_depart!)) {
      setState(() => _error = l10n.errorReturnAfterDeparture);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final id = await ref.read(tripsRepositoryProvider).create(
            departureCountry: _from,
            arrivalCountry: _to,
            departureCity: _fromCity.text.trim(),
            arrivalCity: _toCity.text.trim(),
            departureDate: _depart!,
            returnDate: _ret!,
            maxWeightKg: weight,
            maxItems: items,
            note: _note.text.trim(),
            coverImageUrl: _coverUrl,
          );
      ref.invalidate(myTripsProvider);
      ref.invalidate(feedProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/trips/$id');
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

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    l10n.actionPostATrip,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _countryRow(l10n.labelFrom, _from, _fromCity, (v) => setState(() => _from = v)),
                  const SizedBox(height: 14),
                  _countryRow(l10n.labelTo, _to, _toCity, (v) => setState(() => _to = v)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField(l10n.labelDeparture, _depart, (d) => setState(() => _depart = d)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateField(l10n.labelReturn, _ret, (d) => setState(() => _ret = d)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _weight,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: l10n.fieldSpareWeightKg),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _items,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: l10n.fieldMaxItems),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _note,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.fieldNoteOptional,
                      hintText: l10n.hintNoteTrip,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ImagePickerField(
                    value: _coverUrl,
                    onChanged: (url) => setState(() => _coverUrl = url),
                    label: l10n.fieldCoverPhotoOptional,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.actionPostTrip),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countryRow(
    String label,
    String code,
    TextEditingController city,
    ValueChanged<String> onCountry,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: code,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: [
              for (final c in kLiveCountries) DropdownMenuItem(value: c.code, child: Text(c.name)),
            ],
            onChanged: (v) => onCountry(v ?? code),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: city,
            decoration: InputDecoration(labelText: l10n.fieldCityOptional),
          ),
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPick) {
    return OutlinedButton(
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          firstDate: now,
          lastDate: now.add(const Duration(days: 365)),
          initialDate: value ?? now.add(const Duration(days: 7)),
        );
        if (picked != null) onPick(picked);
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(value == null ? label : shortDate(value)),
      ),
    );
  }
}
