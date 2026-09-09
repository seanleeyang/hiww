import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/cities.dart';
import '../../../core/countries.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/breakdown_row.dart';
import '../../../ui/budget_stepper.dart';
import '../../../ui/category_chips.dart';
import '../../../ui/image_picker_field.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/soft_card.dart';
import '../../discovery/data/discovery_repository.dart';
import '../../shared/data/pricing_repository.dart';
import '../data/wants_repository.dart';

/// Empty-string sentinel for "nothing picked yet" — lets a dropdown show a
/// real "Select" placeholder entry instead of defaulting to a value.
const _unselected = '';

/// Sentinel for "Others" in a city dropdown — reveals a free-text field for
/// a city not in the curated list.
const _othersCity = '__others__';

/// Sentinel for "Any" in the Buy-in city dropdown — a deliberate choice
/// meaning no specific city, distinct from [_unselected] (no choice made).
const _anyCity = '__any__';

/// Matches [sourceCity] against the curated list for [country]: an exact
/// match preselects that city, anything else preselects "Others" with the
/// value carried over into the custom field.
String _initialCityChoice(String country, String? sourceCity) {
  if (sourceCity == null || sourceCity.isEmpty) return _unselected;
  final matches = kCities.any(
    (c) => c.countryCode == country && c.city.toLowerCase() == sourceCity.toLowerCase(),
  );
  return matches ? sourceCity : _othersCity;
}

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
  late String _cityChoice = _initialCityChoice(_country, widget.sourceCity);
  late final _cityCustom = TextEditingController(
    text: _cityChoice == _othersCity ? (widget.sourceCity ?? '') : '',
  );
  String _destCountry = _unselected;
  String _destCityChoice = _unselected;
  final _destCityCustom = TextEditingController();
  int _budget = 3000;
  int _qty = 1;
  DateTime? _needBy;
  String? _error;
  bool _submitting = false;

  bool get _isDirectRequest => widget.targetTripId != null;

  String get _cityValue {
    if (_cityChoice == _othersCity) return _cityCustom.text.trim();
    if (_cityChoice == _unselected || _cityChoice == _anyCity) return '';
    return _cityChoice;
  }

  /// Whether the shopper has made a real choice for Buy-in city — "Any" and
  /// a filled-in "Others" field both count; the empty placeholder and an
  /// empty "Others" field don't. Distinct from [_cityValue], which is the
  /// empty string for "Any" too (no specific city to display/submit).
  bool get _cityIsChosen =>
      _cityChoice != _unselected && (_cityChoice != _othersCity || _cityCustom.text.trim().isNotEmpty);

  String get _destCityValue => _destCityChoice == _othersCity
      ? _destCityCustom.text.trim()
      : (_destCityChoice == _unselected ? '' : _destCityChoice);

  String _initialCountry() {
    final source = widget.sourceCountry;
    return (source != null && isLiveCountry(source)) ? source : _unselected;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _productUrl.dispose();
    _title.dispose();
    _details.dispose();
    _cityCustom.dispose();
    _destCityCustom.dispose();
    super.dispose();
  }

  /// Returns whether every required field is filled; sets [_error] as a
  /// side effect (to the first missing/invalid one) either way.
  bool _validate() {
    final l10n = AppLocalizations.of(context)!;
    final title = _title.text.trim();
    final details = _details.text.trim();
    if (_photoUrl == null || _photoUrl!.isEmpty) {
      _error = l10n.errorPhotoRequired;
      return false;
    }
    if (title.isEmpty) {
      _error = l10n.errorWantTitleBlank;
      return false;
    }
    if (title.length < 3) {
      _error = l10n.errorWantTitleTooShort;
      return false;
    }
    if (details.isEmpty) {
      _error = l10n.errorWantDetailsBlank;
      return false;
    }
    if (details.length < 10) {
      _error = l10n.errorWantDetailsTooShort;
      return false;
    }
    if (_country.isEmpty) {
      _error = l10n.errorBuyInCountryRequired;
      return false;
    }
    if (!_cityIsChosen) {
      _error = l10n.errorBuyInCityRequired;
      return false;
    }
    if (_destCountry.isEmpty) {
      _error = l10n.errorDeliverToCountryRequired;
      return false;
    }
    if (_destCityValue.isEmpty) {
      _error = l10n.errorDeliverToCityRequired;
      return false;
    }
    _error = null;
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
          ImagePickerField(
            value: _photoUrl,
            onChanged: (url) => setState(() => _photoUrl = url),
            label: l10n.fieldPhoto,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.fieldItem,
              hintText: l10n.hintItemExample,
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
            controller: _details,
            maxLines: 2,
            decoration: InputDecoration(hintText: l10n.hintDetails),
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
                    _QtyStepper(
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
                            label: Text(_needBy == null ? l10n.anyTime : shortDate(_needBy)),
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
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _country,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.labelCountry),
                  items: [
                    DropdownMenuItem(value: _unselected, child: Text(l10n.selectOption)),
                    for (final c in kLiveCountries) DropdownMenuItem(value: c.code, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() {
                    _country = v ?? _unselected;
                    _cityChoice = _unselected;
                    _cityCustom.clear();
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
                    DropdownMenuItem(value: _unselected, child: Text(l10n.selectOption)),
                    DropdownMenuItem(value: _anyCity, child: Text(l10n.cityOptionAny)),
                    for (final c in kCities.where((c) => c.countryCode == _country))
                      DropdownMenuItem(value: c.city, child: Text(c.city)),
                    DropdownMenuItem(value: _othersCity, child: Text(l10n.cityOptionOthers)),
                  ],
                  onChanged: _country.isEmpty
                      ? null
                      : (v) => setState(() => _cityChoice = v ?? _unselected),
                ),
              ),
            ],
          ),
          if (_cityChoice == _othersCity) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _cityCustom,
              decoration: InputDecoration(
                labelText: l10n.fieldCity,
                hintText: l10n.hintCityCustom,
              ),
            ),
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
                                l10n.travelersHeadingSoon(m.count, countryName(_country)),
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
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _destCountry,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.labelCountry),
                  items: [
                    DropdownMenuItem(value: _unselected, child: Text(l10n.selectOption)),
                    for (final c in kLiveCountries) DropdownMenuItem(value: c.code, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() {
                    _destCountry = v ?? _unselected;
                    _destCityChoice = _unselected;
                    _destCityCustom.clear();
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
                    DropdownMenuItem(value: _unselected, child: Text(l10n.selectOption)),
                    for (final c in kCities.where((c) => c.countryCode == _destCountry))
                      DropdownMenuItem(value: c.city, child: Text(c.city)),
                    DropdownMenuItem(value: _othersCity, child: Text(l10n.cityOptionOthers)),
                  ],
                  onChanged: _destCountry.isEmpty
                      ? null
                      : (v) => setState(() => _destCityChoice = v ?? _unselected),
                ),
              ),
            ],
          ),
          if (_destCityChoice == _othersCity) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _destCityCustom,
              decoration: InputDecoration(
                labelText: l10n.fieldCity,
                hintText: l10n.hintCityCustom,
              ),
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
          if (_error != null && _page == 0) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
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
                IconLine(Icons.category_outlined, _category),
                const SizedBox(height: 6),
                IconLine(Icons.numbers, l10n.wantQuantityLine(_qty)),
                const SizedBox(height: 6),
                IconLine(
                  Icons.public,
                  l10n.wantBuyInLine(_cityValue.isNotEmpty ? _cityValue : countryName(_country)),
                ),
                const SizedBox(height: 6),
                IconLine(
                  Icons.local_shipping_outlined,
                  l10n.wantDeliverToLine(_destCityValue.isNotEmpty ? _destCityValue : countryName(_destCountry)),
                ),
                if (_needBy != null) ...[
                  const SizedBox(height: 6),
                  IconLine(Icons.event_outlined, 'Need by ${shortDate(_needBy)}'),
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
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isDirectRequest ? l10n.actionSendRequest : l10n.actionPostMyWant),
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

/// "− 2 +" whole-number stepper, clamped to 1–99.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          IconButton(
            onPressed: value < 99 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
