import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/countries.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/budget_stepper.dart';
import '../../../ui/category_chips.dart';
import '../../../ui/image_picker_field.dart';
import '../../discovery/data/discovery_repository.dart';
import '../domain/want_draft.dart';

/// Empty-string sentinel for "no country picked yet" — lets the dropdown
/// show a real "Select" placeholder entry instead of defaulting to a country.
const _unselected = '';

/// Step 1 of creating a want: collects every field, then hands a [WantDraft]
/// to `/wants/new/summary` for review before the actual API call. Pass
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
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _CreateOrderSheet(
        sourceCountry: sourceCountry,
        sourceCity: sourceCity,
        targetTripId: targetTripId,
        targetTravelerName: targetTravelerName,
      ),
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
  final _productUrl = TextEditingController();
  final _title = TextEditingController();
  final _details = TextEditingController();
  late final _city = TextEditingController(text: widget.sourceCity ?? '');
  final _destCity = TextEditingController();
  String? _photoUrl;
  String _category = 'sneakers';
  late String _country = _initialCountry();
  String _destCountry = _unselected;
  int _budget = 3000;
  int _qty = 1;
  DateTime? _needBy;
  String? _error;

  String _initialCountry() {
    final source = widget.sourceCountry;
    return (source != null && isLiveCountry(source)) ? source : _unselected;
  }

  @override
  void dispose() {
    _productUrl.dispose();
    _title.dispose();
    _details.dispose();
    _city.dispose();
    _destCity.dispose();
    super.dispose();
  }

  void _next() {
    final l10n = AppLocalizations.of(context)!;
    final title = _title.text.trim();
    final details = _details.text.trim();
    if (_photoUrl == null || _photoUrl!.isEmpty) {
      setState(() => _error = l10n.errorPhotoRequired);
      return;
    }
    if (title.isEmpty) {
      setState(() => _error = l10n.errorWantTitleBlank);
      return;
    }
    if (title.length < 3) {
      setState(() => _error = l10n.errorWantTitleTooShort);
      return;
    }
    if (details.isEmpty) {
      setState(() => _error = l10n.errorWantDetailsBlank);
      return;
    }
    if (details.length < 10) {
      setState(() => _error = l10n.errorWantDetailsTooShort);
      return;
    }
    if (_country.isEmpty) {
      setState(() => _error = l10n.errorBuyInCountryRequired);
      return;
    }
    if (_city.text.trim().isEmpty) {
      setState(() => _error = l10n.errorBuyInCityRequired);
      return;
    }
    if (_destCountry.isEmpty) {
      setState(() => _error = l10n.errorDeliverToCountryRequired);
      return;
    }
    if (_destCity.text.trim().isEmpty) {
      setState(() => _error = l10n.errorDeliverToCityRequired);
      return;
    }
    setState(() => _error = null);

    final draft = WantDraft(
      productUrl: _productUrl.text.trim().isEmpty ? null : _productUrl.text.trim(),
      imageUrl: _photoUrl,
      title: title,
      itemDescription: details,
      category: _category,
      quantity: _qty,
      needBy: _needBy,
      sourceCountry: _country,
      sourceCity: _city.text.trim(),
      destinationCountry: _destCountry,
      destinationCity: _destCity.text.trim(),
      budget: _budget,
      targetTripId: widget.targetTripId,
      targetTravelerName: widget.targetTravelerName,
    );
    Navigator.of(context).pop();
    context.push('/wants/new/summary', extra: draft);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final routeMatch = _country.isEmpty ? null : ref.watch(routeMatchProvider(_country));
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.targetTripId != null ? l10n.actionRequestFromThisTrip : l10n.actionPostAWant,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
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
            if (widget.targetTripId != null) ...[
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
                      DropdownMenuItem(value: _unselected, child: Text(l10n.selectCountry)),
                      for (final c in kLiveCountries) DropdownMenuItem(value: c.code, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _country = v ?? _unselected),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _city,
                    decoration: InputDecoration(
                      labelText: l10n.fieldCity,
                      hintText: l10n.hintCityExample,
                    ),
                  ),
                ),
              ],
            ),
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
                      DropdownMenuItem(value: _unselected, child: Text(l10n.selectCountry)),
                      for (final c in kLiveCountries) DropdownMenuItem(value: c.code, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _destCountry = v ?? _unselected),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _destCity,
                    decoration: InputDecoration(
                      labelText: l10n.fieldCity,
                      hintText: l10n.hintCityExample,
                    ),
                  ),
                ),
              ],
            ),
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
            if (_error != null) ...[
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
