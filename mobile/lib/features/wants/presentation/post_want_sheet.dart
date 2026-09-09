import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/countries.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/budget_stepper.dart';
import '../../../ui/category_chips.dart';
import '../../../ui/image_picker_field.dart';
import '../../discovery/data/discovery_repository.dart';
import '../data/wants_repository.dart';
import '../domain/want.dart';

/// Edits an existing want in place. Creating a new want is a separate,
/// full-screen flow — see `create_order_screen.dart` (`CreateOrderScreen` +
/// `WantSummaryScreen`, reached via `/wants/new`).
Future<void> showEditWantSheet(BuildContext context, {required Want existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _EditWantSheet(existing: existing),
    ),
  );
}

class _EditWantSheet extends ConsumerStatefulWidget {
  const _EditWantSheet({required this.existing});
  final Want existing;

  @override
  ConsumerState<_EditWantSheet> createState() => _EditWantSheetState();
}

class _EditWantSheetState extends ConsumerState<_EditWantSheet> {
  late final _title = TextEditingController(text: widget.existing.title ?? '');
  late final _details = TextEditingController(text: widget.existing.itemDescription);
  late final _city = TextEditingController(text: widget.existing.sourceCity ?? '');
  late String? _photoUrl = widget.existing.imageUrl;
  late String _category = widget.existing.category;
  late final String _country = widget.existing.sourceCountry;
  late int _budget = double.tryParse(widget.existing.budget)?.round() ?? 3000;
  late int _qty = widget.existing.quantity;
  late DateTime? _needBy = widget.existing.needBy;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _title.text.trim();
    final details = _details.text.trim();
    if (title.length < 3) {
      setState(() => _error = l10n.errorWantTitleTooShort);
      return;
    }
    if (details.length < 10) {
      setState(() => _error = l10n.errorWantDetailsTooShort);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final id = widget.existing.id;
      await ref.read(wantsRepositoryProvider).update(
            id,
            title: title,
            itemDescription: details,
            sourceCity: _city.text.trim(),
            category: _category,
            budget: '${_budget.toStringAsFixed(0)}.00',
            quantity: _qty,
            needBy: _needBy,
            imageUrl: _photoUrl ?? '',
          );
      ref.invalidate(myWantsProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(wantDetailProvider(id));
      if (!mounted) return;
      Navigator.of(context).pop();
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.wantEditTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.fieldItem,
                hintText: l10n.hintItemExample,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _details,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.fieldDetails,
                hintText: l10n.hintDetails,
              ),
            ),
            const SizedBox(height: 12),
            ImagePickerField(
              value: _photoUrl,
              onChanged: (url) => setState(() => _photoUrl = url),
              label: l10n.fieldPhotoOptional,
            ),
            const SizedBox(height: 18),
            Text(l10n.labelCategory, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            CategoryChips(
              includeAll: false,
              selected: _category,
              onSelected: (c) => setState(() => _category = c ?? 'other'),
            ),
            const SizedBox(height: 18),
            Text(l10n.labelBudget, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            BudgetStepper(
              value: _budget,
              onChanged: (v) => setState(() => _budget = v),
            ),
            const SizedBox(height: 4),
            Text(l10n.budgetTotalNote(_qty),
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.labelQuantity,
                          style: Theme.of(context).textTheme.labelLarge),
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
                      Text(
                        l10n.labelNeedBy,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.event_outlined, size: 18),
                              label: Text(
                                _needBy == null ? l10n.anyTime : shortDate(_needBy),
                              ),
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: countryName(_country),
                    enabled: false,
                    decoration: InputDecoration(labelText: l10n.labelBuyIn),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _city,
                    decoration: InputDecoration(
                      labelText: l10n.fieldCityOptional,
                      hintText: l10n.hintCityExample,
                    ),
                  ),
                ),
              ],
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
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.actionSaveChanges),
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
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
