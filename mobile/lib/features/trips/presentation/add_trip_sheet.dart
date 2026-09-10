import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/cities.dart';
import '../../../core/city_choice.dart';
import '../../../core/countries.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/busy_filled_button.dart';
import '../../../ui/image_picker_field.dart';
import '../../discovery/data/discovery_repository.dart';
import '../data/trips_repository.dart';
import 'date_range_sheet.dart';

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
  final _note = TextEditingController();
  final _weight = TextEditingController(text: '8');
  final _items = TextEditingController(text: '5');
  late String _from = widget.fromCountry ?? 'TH';
  late String _to = widget.toCountry ?? 'JP';
  late String _fromCityChoice = initialCityChoice(_from, widget.fromCity);
  late String _toCityChoice = initialCityChoice(_to, widget.toCity);
  late final _fromCityCustom = TextEditingController(
    text: _fromCityChoice == othersCity ? (widget.fromCity ?? '') : '',
  );
  late final _toCityCustom = TextEditingController(
    text: _toCityChoice == othersCity ? (widget.toCity ?? '') : '',
  );
  String? _coverUrl;
  late DateTime? _depart = widget.depart;
  late DateTime? _ret = widget.ret;
  bool _submitting = false;
  String? _error;

  String _cityValueFor(String choice, TextEditingController custom) {
    if (choice == othersCity) return custom.text.trim();
    if (choice == unselected || choice == anyCity) return '';
    return choice;
  }

  @override
  void dispose() {
    _fromCityCustom.dispose();
    _toCityCustom.dispose();
    _note.dispose();
    _weight.dispose();
    _items.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final picked = await showDateRangeSheet(context, initialStart: _depart, initialEnd: _ret);
    if (picked == null) return;
    final (start, end) = picked;
    setState(() {
      _depart = start;
      _ret = end;
    });
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
            departureCity: _cityValueFor(_fromCityChoice, _fromCityCustom),
            arrivalCity: _cityValueFor(_toCityChoice, _toCityCustom),
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
                  Text(l10n.labelFrom, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _countryCityRow(
                    country: _from,
                    onCountryChanged: (v) => setState(() {
                      _from = v;
                      _fromCityChoice = unselected;
                      _fromCityCustom.clear();
                    }),
                    cityChoice: _fromCityChoice,
                    onCityChoiceChanged: (v) => setState(() => _fromCityChoice = v),
                    customCityController: _fromCityCustom,
                    keyPrefix: 'from',
                  ),
                  const SizedBox(height: 18),
                  Text(l10n.labelTo, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _countryCityRow(
                    country: _to,
                    onCountryChanged: (v) => setState(() {
                      _to = v;
                      _toCityChoice = unselected;
                      _toCityCustom.clear();
                    }),
                    cityChoice: _toCityChoice,
                    onCityChoiceChanged: (v) => setState(() => _toCityChoice = v),
                    customCityController: _toCityCustom,
                    keyPrefix: 'to',
                  ),
                  const SizedBox(height: 18),
                  Text(l10n.labelTravelDates, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickDates,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        (_depart != null && _ret != null)
                            ? '${shortDate(_depart)} – ${shortDate(_ret)}'
                            : l10n.labelTravelDates,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      alignment: Alignment.centerLeft,
                    ),
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
                  BusyFilledButton(
                    busy: _submitting,
                    label: l10n.actionPostTrip,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countryCityRow({
    required String country,
    required ValueChanged<String> onCountryChanged,
    required String cityChoice,
    required ValueChanged<String> onCityChoiceChanged,
    required TextEditingController customCityController,
    required String keyPrefix,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: country,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.labelCountry),
                items: [
                  for (final c in kLiveCountries) DropdownMenuItem(value: c.code, child: Text(c.name)),
                ],
                onChanged: (v) => onCountryChanged(v ?? country),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('$keyPrefix-city-$country'),
                initialValue: cityChoice,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.fieldCity),
                items: [
                  DropdownMenuItem(value: unselected, child: Text(l10n.selectOption)),
                  DropdownMenuItem(value: anyCity, child: Text(l10n.cityOptionAny)),
                  for (final c in kCities.where((c) => c.countryCode == country))
                    DropdownMenuItem(value: c.city, child: Text(c.city)),
                  DropdownMenuItem(value: othersCity, child: Text(l10n.cityOptionOthers)),
                ],
                onChanged: (v) => onCityChoiceChanged(v ?? unselected),
              ),
            ),
          ],
        ),
        if (cityChoice == othersCity) ...[
          const SizedBox(height: 8),
          TextField(
            controller: customCityController,
            decoration: InputDecoration(
              labelText: l10n.fieldCity,
              hintText: l10n.hintCityCustom,
            ),
          ),
        ],
      ],
    );
  }
}
