import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/cities.dart';
import '../../../core/city_choice.dart';
import '../../../core/countries.dart';
import '../../../core/format.dart';
import '../../../core/thai_geography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/busy_filled_button.dart';
import '../../../ui/image_picker_field.dart';
import '../../discovery/data/discovery_repository.dart';
import '../data/trips_repository.dart';
import 'date_range_sheet.dart';

/// Posting a new trip is a near-full-height bottom sheet with two swipeable
/// pages — the form, then a Summary review — matching the Post a Want flow's
/// presentation (`create_order_sheet.dart`). Both are the app's "create from
/// scratch" flows reached via a prominent FAB, so they share this shape;
/// editing an existing trip is reached by drilling into a trip you already
/// posted, so it stays a simpler single-page full-screen form instead — see
/// `new_trip_screen.dart`'s `EditTripScreen`.
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
  final _pageController = PageController();
  int _page = 0;

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

  final _datesKey = GlobalKey();
  final _weightItemsKey = GlobalKey();
  String? _datesError;
  String? _weightItemsError;

  /// All 77 Thai provinces, for the From/To city dropdowns when Thailand is
  /// chosen — see the matching field in `create_order_sheet.dart` for detail.
  List<ThaiProvince> _thaiProvinces = [];

  @override
  void initState() {
    super.initState();
    ThaiGeography.load().then((geo) {
      if (mounted) setState(() => _thaiProvinces = geo.provinces);
    });
  }

  String _cityValueFor(String choice, TextEditingController custom) {
    if (choice == othersCity) return custom.text.trim();
    if (choice == unselected || choice == anyCity) return '';
    return choice;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fromCityCustom.dispose();
    _toCityCustom.dispose();
    _note.dispose();
    _weight.dispose();
    _items.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final picked = await showDateRangeSheet(
      context,
      initialStart: _depart,
      initialEnd: _ret,
    );
    if (picked == null) return;
    final (start, end) = picked;
    setState(() {
      _depart = start;
      _ret = end;
      _datesError = null;
    });
  }

  /// Returns whether every required field is filled; sets each field's own
  /// error message and scrolls to the first invalid one as a side effect.
  bool _validateForm() {
    final l10n = AppLocalizations.of(context)!;
    final weight = double.tryParse(_weight.text.trim());
    final items = int.tryParse(_items.text.trim());

    String? datesError;
    if (_depart == null || _ret == null) {
      datesError = l10n.errorPickTravelDates;
    } else if (!_ret!.isAfter(_depart!)) {
      datesError = l10n.errorReturnAfterDeparture;
    }
    final weightItemsError =
        (weight == null || weight <= 0 || items == null || items <= 0)
        ? l10n.errorEnterWeightAndItems
        : null;

    setState(() {
      _datesError = datesError;
      _weightItemsError = weightItemsError;
    });

    if (datesError != null || weightItemsError != null) {
      final target = datesError != null ? _datesKey : _weightItemsKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = target.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
            alignment: 0.2,
          );
        }
      });
      return false;
    }
    return true;
  }

  void _next() {
    if (_validateForm()) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  /// Swiping straight to the Summary page bypasses the "Next" button, so
  /// validate here too — bounce back to the form (with errors showing) if
  /// something required is still missing.
  void _onPageChanged(int index) {
    if (index == 1 && !_validateForm()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goToPage(0);
      });
    }
    setState(() => _page = index);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(tripsRepositoryProvider)
          .create(
            departureCountry: _from,
            arrivalCountry: _to,
            departureCity: _cityValueFor(_fromCityChoice, _fromCityCustom),
            arrivalCity: _cityValueFor(_toCityChoice, _toCityCustom),
            departureDate: _depart!,
            returnDate: _ret!,
            maxWeightKg: double.parse(_weight.text.trim()),
            maxItems: int.parse(_items.text.trim()),
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
                SizedBox(
                  width: 48,
                  child: _page == 1
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => _goToPage(0),
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    _page == 0 ? l10n.actionPostATrip : l10n.summaryScreenTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
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
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _buildFormPage(context, l10n),
                _buildSummaryPage(context, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPage(BuildContext context, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
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
          Text(
            l10n.labelTravelDates,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Column(
            key: _datesKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await _pickDates();
                  if (_datesError != null) setState(() => _datesError = null);
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    (_depart != null && _ret != null)
                        ? '${shortDate(l10n, _depart)} – ${shortDate(l10n, _ret)}'
                        : l10n.labelTravelDates,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  alignment: Alignment.centerLeft,
                  side: _datesError != null
                      ? BorderSide(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
              ),
              if (_datesError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _datesError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            key: _weightItemsKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (_weightItemsError != null) {
                      setState(() => _weightItemsError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: l10n.fieldSpareWeightKg,
                    errorText: _weightItemsError,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _items,
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (_weightItemsError != null) {
                      setState(() => _weightItemsError = null);
                    }
                  },
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
          const SizedBox(height: 22),
          FilledButton(onPressed: _next, child: Text(l10n.actionNext)),
        ],
      ),
    );
  }

  Widget _buildSummaryPage(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_coverUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _coverUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 14),
          ],
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flight_takeoff, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${countryName(_from, l10n.localeName)} → ${countryName(_to, l10n.localeName)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.event_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text('${shortDate(l10n, _depart)} – ${shortDate(l10n, _ret)}'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.luggage_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        '${_weight.text.trim()} kg · ${_items.text.trim()} ${l10n.fieldMaxItems}',
                      ),
                    ],
                  ),
                  if (_note.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_outlined, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_note.text.trim())),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 20),
          BusyFilledButton(
            busy: _submitting,
            label: l10n.actionPostTrip,
            onPressed: _submit,
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
                  for (final c in kLiveCountries)
                    DropdownMenuItem(value: c.code, child: Text(c.name)),
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
                  DropdownMenuItem(
                    value: unselected,
                    child: Text(l10n.selectOption),
                  ),
                  DropdownMenuItem(
                    value: anyCity,
                    child: Text(l10n.cityOptionAny),
                  ),
                  for (final city in cityNamesForDropdown(country, _thaiProvinces))
                    DropdownMenuItem(value: city, child: Text(city)),
                  DropdownMenuItem(
                    value: othersCity,
                    child: Text(l10n.cityOptionOthers),
                  ),
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
