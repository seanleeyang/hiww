import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/cities.dart';
import '../../../core/city_choice.dart';
import '../../../core/countries.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/breakdown_row.dart';
import '../../../ui/budget_stepper.dart';
import '../../../ui/category_chips.dart';
import '../../../ui/image_picker_field.dart';
import '../../../ui/busy_filled_button.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/qty_stepper.dart';
import '../../../ui/soft_card.dart';
import '../../discovery/data/discovery_repository.dart';
import '../../shared/data/pricing_repository.dart';
import '../data/wants_repository.dart';

/// Creating a want is a near-full-height bottom sheet with two swipeable
/// pages — the form, then a Summary review — not separate routes. Pass
/// [targetTripId] for "Request from this trip" — sends the want directly and
/// privately to that trip's traveler instead of posting it publicly.
///
/// Editing an existing want is a separate, simpler flow — see
/// `post_want_sheet.dart`'s `showEditWantSheet`.
Future<void> showCreateOrderSheet(
  BuildContext context, {
  String? sourceCountry,
  String? sourceCity,
  String? targetTripId,
  String? targetTravelerName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CreateOrderSheet(
      sourceCountry: sourceCountry,
      sourceCity: sourceCity,
      targetTripId: targetTripId,
      targetTravelerName: targetTravelerName,
    ),
  );
}

class _CreateOrderSheet extends ConsumerStatefulWidget {
  const _CreateOrderSheet({
    this.sourceCountry,
    this.sourceCity,
    this.targetTripId,
    this.targetTravelerName,
  });

  final String? sourceCountry;
  final String? sourceCity;
  final String? targetTripId;
  final String? targetTravelerName;

  @override
  ConsumerState<_CreateOrderSheet> createState() => _CreateOrderSheetState();
}

class _CreateOrderSheetState extends ConsumerState<_CreateOrderSheet> {
  final _pageController = PageController();
  int _page = 0;

  final _productUrl = TextEditingController();
  final _title = TextEditingController();
  final _details = TextEditingController();
  String? _photoUrl;
  String _category = 'sneakers';
  late String _country = _initialCountry();
  late String _cityChoice = initialCityChoice(_country, widget.sourceCity);
  late final _cityCustom = TextEditingController(
    text: _cityChoice == othersCity ? (widget.sourceCity ?? '') : '',
  );
  String _destCountry = unselected;
  String _destCityChoice = unselected;
  final _destCityCustom = TextEditingController();
  bool _deliverySameAsRegistered = true;
  final _deliveryStreet = TextEditingController();
  final _deliveryStreet2 = TextEditingController();
  final _deliverySubdistrict = TextEditingController();
  final _deliveryDistrict = TextEditingController();
  final _deliveryPostalCode = TextEditingController();
  int _budget = 3000;
  int _qty = 1;
  DateTime? _needBy;
  String? _error;
  bool _submitting = false;

  final _photoKey = GlobalKey();
  final _titleKey = GlobalKey();
  final _detailsKey = GlobalKey();
  final _buyInKey = GlobalKey();
  final _deliverToKey = GlobalKey();
  final _deliveryAddressKey = GlobalKey();
  String? _photoError;
  String? _titleError;
  String? _detailsError;
  String? _buyInError;
  String? _deliverToError;
  String? _deliveryAddressError;

  bool get _isDirectRequest => widget.targetTripId != null;

  /// `_category` stores the lowercase id (e.g. "beauty") CategoryChips uses
  /// as a value — look up its localized display label (e.g. "Beauty") for
  /// anywhere the category is actually shown to the user.
  String get _categoryLabel => categoryLabel(AppLocalizations.of(context)!, _category);

  String get _cityValue {
    if (_cityChoice == othersCity) return _cityCustom.text.trim();
    if (_cityChoice == unselected || _cityChoice == anyCity) return '';
    return _cityChoice;
  }

  /// Whether the shopper has made a real choice for Buy-in city — "Any" and
  /// a filled-in "Others" field both count; the empty placeholder and an
  /// empty "Others" field don't. Distinct from [_cityValue], which is the
  /// empty string for "Any" too (no specific city to display/submit).
  bool get _cityIsChosen =>
      _cityChoice != unselected && (_cityChoice != othersCity || _cityCustom.text.trim().isNotEmpty);

  String get _destCityValue => _destCityChoice == othersCity
      ? _destCityCustom.text.trim()
      : (_destCityChoice == unselected ? '' : _destCityChoice);

  String _initialCountry() {
    final source = widget.sourceCountry;
    return (source != null && isLiveCountry(source)) ? source : unselected;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _productUrl.dispose();
    _title.dispose();
    _details.dispose();
    _cityCustom.dispose();
    _destCityCustom.dispose();
    _deliveryStreet.dispose();
    _deliveryStreet2.dispose();
    _deliverySubdistrict.dispose();
    _deliveryDistrict.dispose();
    _deliveryPostalCode.dispose();
    super.dispose();
  }

  /// Returns whether every required field is filled; sets each field's own
  /// error message as a side effect and scrolls to the first invalid one.
  bool _validate() {
    final l10n = AppLocalizations.of(context)!;
    final title = _title.text.trim();
    final details = _details.text.trim();

    _photoError = (_photoUrl == null || _photoUrl!.isEmpty) ? l10n.errorPhotoRequired : null;
    _titleError = title.isEmpty
        ? l10n.errorWantTitleBlank
        : (title.length < 3 ? l10n.errorWantTitleTooShort : null);
    _detailsError = details.isEmpty
        ? l10n.errorWantDetailsBlank
        : (details.length < 10 ? l10n.errorWantDetailsTooShort : null);
    _buyInError = _country.isEmpty
        ? l10n.errorBuyInCountryRequired
        : (!_cityIsChosen ? l10n.errorBuyInCityRequired : null);
    _deliverToError = _destCountry.isEmpty
        ? l10n.errorDeliverToCountryRequired
        : (_destCityValue.isEmpty ? l10n.errorDeliverToCityRequired : null);
    _deliveryAddressError = (!_deliverySameAsRegistered &&
            (_deliveryStreet.text.trim().isEmpty || _deliveryPostalCode.text.trim().isEmpty))
        ? l10n.errorDeliveryAddressRequired
        : null;

    GlobalKey? firstInvalid;
    if (_photoError != null) firstInvalid ??= _photoKey;
    if (_titleError != null) firstInvalid ??= _titleKey;
    if (_detailsError != null) firstInvalid ??= _detailsKey;
    if (_buyInError != null) firstInvalid ??= _buyInKey;
    if (_deliverToError != null) firstInvalid ??= _deliverToKey;
    if (_deliveryAddressError != null) firstInvalid ??= _deliveryAddressKey;

    final scrollTarget = firstInvalid;
    if (scrollTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = scrollTarget.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.2);
        }
      });
      return false;
    }
    return true;
  }

  void _next() {
    final ok = _validate();
    setState(() {});
    if (ok) {
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
    }
  }

  void _goToPage(int index) {
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
  }

  /// Swiping straight to the Summary page bypasses the "Next" button, so
  /// validate here too — bounce back to the form (with the error showing)
  /// if something required is still missing.
  void _onPageChanged(int index) {
    if (index == 1 && !_validate()) {
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
      final id = await ref.read(wantsRepositoryProvider).create(
            title: _title.text.trim(),
            itemDescription: _details.text.trim(),
            sourceCountry: _country,
            sourceCity: _cityValue,
            category: _category,
            estimatedWeightKg: 1,
            budget: '${_budget.toStringAsFixed(0)}.00',
            quantity: _qty,
            needBy: _needBy,
            imageUrl: _photoUrl,
            targetTripId: widget.targetTripId,
            destinationCountry: _destCountry,
            destinationCity: _destCityValue,
            productUrl: _productUrl.text.trim().isEmpty ? null : _productUrl.text.trim(),
            deliverySameAsRegistered: _deliverySameAsRegistered,
            deliveryAddressStreet: _deliverySameAsRegistered ? null : _deliveryStreet.text.trim(),
            deliveryAddressStreet2: _deliverySameAsRegistered ? null : _deliveryStreet2.text.trim(),
            deliveryAddressSubdistrict: _deliverySameAsRegistered ? null : _deliverySubdistrict.text.trim(),
            deliveryAddressDistrict: _deliverySameAsRegistered ? null : _deliveryDistrict.text.trim(),
            deliveryAddressPostalCode: _deliverySameAsRegistered ? null : _deliveryPostalCode.text.trim(),
          );
      ref.invalidate(myWantsProvider);
      ref.invalidate(feedProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/wants/$id');
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
                    _page == 0
                        ? (_isDirectRequest ? l10n.actionRequestFromThisTrip : l10n.actionPostAWant)
                        : l10n.summaryScreenTitle,
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
    final routeMatch = _country.isEmpty ? null : ref.watch(routeMatchProvider(_country));
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 18, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.proTipTitle,
                        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onTertiaryContainer),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.proTipCreateOrderBody,
                        style: TextStyle(fontSize: 13, color: scheme.onTertiaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isDirectRequest) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 18, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.directRequestNotice(widget.targetTravelerName ?? l10n.fallbackATraveler),
                      style: TextStyle(fontSize: 13, color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _productUrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.fieldProductUrlOptional,
              hintText: l10n.hintProductUrl,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            key: _photoKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImagePickerField(
                value: _photoUrl,
                onChanged: (url) => setState(() {
                  _photoUrl = url;
                  _photoError = null;
                }),
                label: l10n.fieldPhoto,
              ),
              if (_photoError != null) ...[
                const SizedBox(height: 4),
                Text(_photoError!, style: TextStyle(color: scheme.error, fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: _titleKey,
            controller: _title,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
            decoration: InputDecoration(
              labelText: l10n.fieldItem,
              hintText: l10n.hintItemExample,
              errorText: _titleError,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(l10n.fieldDetails, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 4),
              Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                message: l10n.tooltipProductDetails,
                child: Icon(Icons.help_outline, size: 14, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: _detailsKey,
            controller: _details,
            maxLines: 2,
            onChanged: (_) {
              if (_detailsError != null) setState(() => _detailsError = null);
            },
            decoration: InputDecoration(hintText: l10n.hintDetails, errorText: _detailsError),
          ),
          const SizedBox(height: 14),
          Text(l10n.labelCategory, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          CategoryChips(
            includeAll: false,
            selected: _category,
            onSelected: (c) => setState(() => _category = c ?? 'other'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.labelQuantity, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    QtyStepper(
                      value: _qty,
                      onChanged: (v) => setState(() => _qty = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(l10n.labelNeedBy, style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(width: 4),
                        Tooltip(
                          triggerMode: TooltipTriggerMode.tap,
                          message: l10n.tooltipNeedBy,
                          child: Icon(Icons.help_outline, size: 14, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.event_outlined, size: 18),
                            label: Text(_needBy == null ? l10n.anyTime : shortDate(l10n, _needBy)),
                          ),
                        ),
                        if (_needBy != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => setState(() => _needBy = null),
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: l10n.anyTime,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(l10n.labelBuyIn, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            key: _buyInKey,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _country,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.labelCountry),
                  items: [
                    DropdownMenuItem(value: unselected, child: Text(l10n.selectOption)),
                    for (final c in kLiveCountries) DropdownMenuItem(value: c.code, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() {
                    _country = v ?? unselected;
                    _cityChoice = unselected;
                    _cityCustom.clear();
                    _buyInError = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('buy-in-city-$_country'),
                  initialValue: _cityChoice,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.fieldCity),
                  items: [
                    DropdownMenuItem(value: unselected, child: Text(l10n.selectOption)),
                    DropdownMenuItem(value: anyCity, child: Text(l10n.cityOptionAny)),
                    for (final c in kCities.where((c) => c.countryCode == _country))
                      DropdownMenuItem(value: c.city, child: Text(c.city)),
                    DropdownMenuItem(value: othersCity, child: Text(l10n.cityOptionOthers)),
                  ],
                  onChanged: _country.isEmpty
                      ? null
                      : (v) => setState(() {
                            _cityChoice = v ?? unselected;
                            _buyInError = null;
                          }),
                ),
              ),
            ],
          ),
          if (_cityChoice == othersCity) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _cityCustom,
              onChanged: (_) {
                if (_buyInError != null) setState(() => _buyInError = null);
              },
              decoration: InputDecoration(
                labelText: l10n.fieldCity,
                hintText: l10n.hintCityCustom,
              ),
            ),
          ],
          if (_buyInError != null) ...[
            const SizedBox(height: 4),
            Text(_buyInError!, style: TextStyle(color: scheme.error, fontSize: 12)),
          ],
          if (routeMatch != null) ...[
            const SizedBox(height: 4),
            routeMatch.maybeWhen(
              data: (m) => m.count == 0
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.flight_takeoff, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.travelersHeadingSoon(m.count, countryName(_country, l10n.localeName)),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
          const SizedBox(height: 18),
          Text(l10n.labelDeliverTo, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            key: _deliverToKey,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _destCountry,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.labelCountry),
                  items: [
                    DropdownMenuItem(value: unselected, child: Text(l10n.selectOption)),
                    for (final c in kLiveCountries) DropdownMenuItem(value: c.code, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() {
                    _destCountry = v ?? unselected;
                    _destCityChoice = unselected;
                    _destCityCustom.clear();
                    _deliverToError = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('deliver-to-city-$_destCountry'),
                  initialValue: _destCityChoice,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.fieldCity),
                  items: [
                    DropdownMenuItem(value: unselected, child: Text(l10n.selectOption)),
                    for (final c in kCities.where((c) => c.countryCode == _destCountry))
                      DropdownMenuItem(value: c.city, child: Text(c.city)),
                    DropdownMenuItem(value: othersCity, child: Text(l10n.cityOptionOthers)),
                  ],
                  onChanged: _destCountry.isEmpty
                      ? null
                      : (v) => setState(() {
                            _destCityChoice = v ?? unselected;
                            _deliverToError = null;
                          }),
                ),
              ),
            ],
          ),
          if (_destCityChoice == othersCity) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _destCityCustom,
              onChanged: (_) {
                if (_deliverToError != null) setState(() => _deliverToError = null);
              },
              decoration: InputDecoration(
                labelText: l10n.fieldCity,
                hintText: l10n.hintCityCustom,
              ),
            ),
          ],
          if (_deliverToError != null) ...[
            const SizedBox(height: 4),
            Text(_deliverToError!, style: TextStyle(color: scheme.error, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _deliverySameAsRegistered,
            onChanged: (v) => setState(() => _deliverySameAsRegistered = v ?? true),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.labelSameAsRegisteredAddress),
          ),
          if (!_deliverySameAsRegistered) ...[
            const SizedBox(height: 4),
            Column(
              key: _deliveryAddressKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _deliveryStreet,
                  onChanged: (_) {
                    if (_deliveryAddressError != null) setState(() => _deliveryAddressError = null);
                  },
                  decoration: InputDecoration(labelText: l10n.fieldStreetAddress),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deliveryStreet2,
                  decoration: InputDecoration(labelText: l10n.fieldStreetAddress2),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deliveryDistrict,
                  decoration: InputDecoration(labelText: l10n.fieldDistrict),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deliverySubdistrict,
                  decoration: InputDecoration(labelText: l10n.fieldSubdistrict),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deliveryPostalCode,
                  onChanged: (_) {
                    if (_deliveryAddressError != null) setState(() => _deliveryAddressError = null);
                  },
                  decoration: InputDecoration(labelText: l10n.fieldPostalCode),
                ),
                if (_deliveryAddressError != null) ...[
                  const SizedBox(height: 4),
                  Text(_deliveryAddressError!, style: TextStyle(color: scheme.error, fontSize: 12)),
                ],
              ],
            ),
          ],
          const SizedBox(height: 18),
          Text(l10n.labelBudget, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          BudgetStepper(
            value: _budget,
            onChanged: (v) => setState(() => _budget = v),
          ),
          if (_qty > 1) ...[
            const SizedBox(height: 4),
            Text(
              l10n.budgetTotalNote(_qty),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _next,
            child: Text(l10n.actionNext),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPage(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final title = _title.text.trim();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_photoUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(_photoUrl!, width: 56, height: 56, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isDirectRequest) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 18, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.directRequestNotice(widget.targetTravelerName ?? l10n.fallbackATraveler),
                      style: TextStyle(fontSize: 13, color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_productUrl.text.trim().isNotEmpty) ...[
                  IconLine(Icons.link, l10n.wantProductUrlLine(_productUrl.text.trim())),
                  const SizedBox(height: 8),
                ],
                Text(_details.text.trim()),
                const SizedBox(height: 10),
                IconLine(Icons.category_outlined, _categoryLabel),
                const SizedBox(height: 6),
                IconLine(Icons.numbers, l10n.wantQuantityLine(_qty)),
                const SizedBox(height: 6),
                IconLine(
                  Icons.public,
                  l10n.wantBuyInLine(
                      _cityValue.isNotEmpty ? _cityValue : countryName(_country, l10n.localeName)),
                ),
                const SizedBox(height: 6),
                IconLine(
                  Icons.local_shipping_outlined,
                  l10n.wantDeliverToLine(
                      _destCityValue.isNotEmpty ? _destCityValue : countryName(_destCountry, l10n.localeName)),
                ),
                if (_needBy != null) ...[
                  const SizedBox(height: 6),
                  IconLine(Icons.event_outlined, l10n.needByDate(shortDate(l10n, _needBy))),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SoftCard(
            child: ref.watch(pricingPreviewProvider(_budget.toString())).when(
                  data: (p) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BreakdownRow(l10n.priceBreakdownProductPrice, p.itemPriceLabel),
                      BreakdownRow(l10n.priceBreakdownTravellerReward, p.travellerRewardLabel),
                      BreakdownRow(l10n.priceBreakdownServiceFee, p.serviceFeeLabel),
                      const Divider(height: 16),
                      BreakdownRow(l10n.priceBreakdownTotal, p.shopperTotalLabel, bold: true),
                    ],
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
                  // Don't block review over a display-only preview failing —
                  // fall back to the plain budget figure.
                  error: (_, _) => IconLine(Icons.sell_outlined, l10n.wantBudgetLine(money(_budget))),
                ),
          ),
          if (_error != null && _page == 1) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 20),
          BusyFilledButton(
            busy: _submitting,
            label: _isDirectRequest ? l10n.actionSendRequest : l10n.actionPostMyWant,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _needBy ?? now.add(const Duration(days: 14)),
    );
    if (picked != null) setState(() => _needBy = picked);
  }
}
