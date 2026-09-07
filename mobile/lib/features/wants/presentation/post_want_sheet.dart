import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/countries.dart';
import '../../../core/format.dart';
import '../../../ui/budget_stepper.dart';
import '../../../ui/category_chips.dart';
import '../../../ui/image_picker_field.dart';
import '../../discovery/data/discovery_repository.dart';
import '../data/wants_repository.dart';
import '../domain/want.dart';

/// Pass [existing] to edit that want in place instead of posting a new one.
/// Pass [targetTripId] for "Request from this trip" — this sends the want
/// directly and privately to that trip's traveler instead of posting it
/// publicly for any traveler to see and offer on.
Future<void> showPostWantSheet(
  BuildContext context, {
  String? sourceCountry,
  String? sourceCity,
  String? targetTripId,
  String? targetTravelerName,
  Want? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _PostWantSheet(
        sourceCountry: sourceCountry,
        sourceCity: sourceCity,
        targetTripId: targetTripId,
        targetTravelerName: targetTravelerName,
        existing: existing,
      ),
    ),
  );
}

class _PostWantSheet extends ConsumerStatefulWidget {
  const _PostWantSheet({
    this.sourceCountry,
    this.sourceCity,
    this.targetTripId,
    this.targetTravelerName,
    this.existing,
  });
  final String? sourceCountry;
  final String? sourceCity;
  final String? targetTripId;
  final String? targetTravelerName;
  final Want? existing;

  @override
  ConsumerState<_PostWantSheet> createState() => _PostWantSheetState();
}

class _PostWantSheetState extends ConsumerState<_PostWantSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _details = TextEditingController(text: widget.existing?.itemDescription ?? '');
  late final _city = TextEditingController(
    text: widget.existing?.sourceCity ?? widget.sourceCity ?? '',
  );
  late String? _photoUrl = widget.existing?.imageUrl;
  late String _category = widget.existing?.category ?? 'sneakers';
  late String _country = _initialCountry();
  late int _budget = widget.existing != null
      ? (double.tryParse(widget.existing!.budget)?.round() ?? 3000)
      : 3000;
  late int _qty = widget.existing?.quantity ?? 1;
  late DateTime? _needBy = widget.existing?.needBy;
  bool _submitting = false;
  String? _error;

  bool get _editing => widget.existing != null;

  String _initialCountry() {
    final existingCountry = widget.existing?.sourceCountry;
    if (existingCountry != null && isLiveCountry(existingCountry)) return existingCountry;
    final source = widget.sourceCountry;
    return (source != null && isLiveCountry(source)) ? source : 'JP';
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final details = _details.text.trim();
    if (title.length < 3) {
      setState(() => _error = 'Give your want a short name');
      return;
    }
    if (details.length < 10) {
      setState(() => _error = 'Add a few details (at least 10 characters)');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_editing) {
        final id = widget.existing!.id;
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
      } else {
        final id = await ref
            .read(wantsRepositoryProvider)
            .create(
              title: title,
              itemDescription: details,
              sourceCountry: _country,
              sourceCity: _city.text.trim(),
              category: _category,
              estimatedWeightKg: 1,
              budget: '${_budget.toStringAsFixed(0)}.00',
              quantity: _qty,
              needBy: _needBy,
              imageUrl: _photoUrl ?? '',
              targetTripId: widget.targetTripId,
            );
        ref.invalidate(myWantsProvider);
        ref.invalidate(feedProvider);
        if (!mounted) return;
        Navigator.of(context).pop();
        context.push('/wants/$id');
      }
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
    final routeMatch = ref.watch(routeMatchProvider(_country));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editing
                  ? 'Edit want'
                  : widget.targetTripId != null
                      ? 'Request from this trip'
                      : 'Post a want',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!_editing && widget.targetTripId != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sent directly to ${widget.targetTravelerName ?? 'the traveler'} — not shown '
                        'publicly. Your budget below is your opening price; they can accept, '
                        'counter, or decline.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Item',
                hintText: 'e.g. Nike Dunk Panda',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _details,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Details',
                hintText: 'Brand, model, size, colour, links',
              ),
            ),
            const SizedBox(height: 12),
            ImagePickerField(
              value: _photoUrl,
              onChanged: (url) => setState(() => _photoUrl = url),
              label: 'Add a photo (optional)',
            ),
            const SizedBox(height: 18),
            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            CategoryChips(
              includeAll: false,
              selected: _category,
              onSelected: (c) => setState(() => _category = c ?? 'other'),
            ),
            const SizedBox(height: 18),
            Text('Budget', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            BudgetStepper(
              value: _budget,
              onChanged: (v) => setState(() => _budget = v),
            ),
            const SizedBox(height: 4),
            Text('Total you expect to pay, for all ${pluralize(_qty, 'item')}.',
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
                      Text('Quantity',
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
                        'Need by',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.event_outlined, size: 18),
                        label: Text(
                          _needBy == null ? 'Any time' : shortDate(_needBy),
                        ),
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
                  child: _editing
                      ? TextFormField(
                          initialValue: countryName(_country),
                          enabled: false,
                          decoration: const InputDecoration(labelText: 'Buy in'),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: _country,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Buy in'),
                          items: [
                            for (final c in kLiveCountries)
                              DropdownMenuItem(value: c.code, child: Text(c.name)),
                          ],
                          onChanged: (v) => setState(() => _country = v ?? 'JP'),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _city,
                    decoration: const InputDecoration(
                      labelText: 'City (optional)',
                      hintText: 'Tokyo',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            routeMatch.maybeWhen(
              data: (m) => m.count == 0
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flight_takeoff, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${pluralize(m.count, 'traveler')} heading to '
                              '${countryName(_country)} soon',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
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
                  : Text(_editing
                      ? 'Save changes'
                      : widget.targetTripId != null
                          ? 'Send request'
                          : 'Post my want'),
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
