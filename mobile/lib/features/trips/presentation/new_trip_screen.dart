import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/countries.dart';
import '../../../core/format.dart';
import '../../../ui/image_picker_field.dart';
import '../../discovery/data/discovery_repository.dart';
import '../data/trips_repository.dart';
import '../domain/trip.dart';

/// Doubles as the edit form: pass [existing] to prefill and switch the
/// submit action from create to update. Route (departure/arrival country)
/// is never editable — see the schema-side comment for why.
class NewTripScreen extends ConsumerStatefulWidget {
  const NewTripScreen({super.key, this.existing});
  final Trip? existing;

  @override
  ConsumerState<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends ConsumerState<NewTripScreen> {
  late final _fromCity = TextEditingController(text: widget.existing?.departureCity ?? '');
  late final _toCity = TextEditingController(text: widget.existing?.arrivalCity ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late final _weight = TextEditingController(
    text: widget.existing == null ? '8' : widget.existing!.maxWeightKg.toString(),
  );
  late final _items = TextEditingController(
    text: widget.existing == null ? '5' : widget.existing!.maxItems.toString(),
  );
  late String _from = widget.existing?.departureCountry ?? 'TH';
  late String _to = widget.existing?.arrivalCountry ?? 'JP';
  late String? _coverUrl = widget.existing?.coverImageUrl;
  late DateTime? _depart = widget.existing?.departureDate;
  late DateTime? _ret = widget.existing?.returnDate;
  bool _submitting = false;
  String? _error;

  bool get _editing => widget.existing != null;

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
    final weight = double.tryParse(_weight.text.trim());
    final items = int.tryParse(_items.text.trim());
    if (_depart == null || _ret == null) {
      setState(() => _error = 'Pick your travel dates');
      return;
    }
    if (weight == null || weight <= 0 || items == null || items <= 0) {
      setState(() => _error = 'Enter spare weight and item count');
      return;
    }
    if (!_ret!.isAfter(_depart!)) {
      setState(() => _error = 'Return date must be after departure');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_editing) {
        final id = widget.existing!.id;
        await ref.read(tripsRepositoryProvider).update(
              id,
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
        ref.invalidate(tripDetailProvider(id));
        if (!mounted) return;
        context.pop();
      } else {
        final id = await ref
            .read(tripsRepositoryProvider)
            .create(
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
        context.pop();
        context.push('/trips/$id');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  Future<void> _cancelTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this trip?'),
        content: const Text(
          'Shoppers will no longer be able to find or offer against this trip. '
          'This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Keep trip')),
          FilledButton(
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Cancel trip'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      final id = widget.existing!.id;
      await ref.read(tripsRepositoryProvider).cancel(id);
      ref.invalidate(myTripsProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(tripDetailProvider(id));
      if (!mounted) return;
      context.pop();
      context.pop();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit trip' : 'Post a trip'),
        actions: [
          if (_editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Cancel trip',
              onPressed: _submitting ? null : _cancelTrip,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _countryRow(
            'From',
            _from,
            _fromCity,
            (v) => setState(() => _from = v),
          ),
          const SizedBox(height: 14),
          _countryRow('To', _to, _toCity, (v) => setState(() => _to = v)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _dateField(
                  'Departure',
                  _depart,
                  (d) => setState(() => _depart = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dateField(
                  'Return',
                  _ret,
                  (d) => setState(() => _ret = d),
                ),
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
                  decoration: const InputDecoration(
                    labelText: 'Spare weight (kg)',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _items,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max items'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'What you can carry, preferences…',
            ),
          ),
          const SizedBox(height: 14),
          ImagePickerField(
            value: _coverUrl,
            onChanged: (url) => setState(() => _coverUrl = url),
            label: 'Add a cover photo (optional)',
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
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
                : Text(_editing ? 'Save changes' : 'Post trip'),
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
    return Row(
      children: [
        Expanded(
          child: _editing
              ? TextFormField(
                  initialValue: countryName(code),
                  enabled: false,
                  decoration: InputDecoration(labelText: label),
                )
              : DropdownButtonFormField<String>(
                  initialValue: code,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: label),
                  items: [
                    for (final c in kLiveCountries)
                      DropdownMenuItem(value: c.code, child: Text(c.name)),
                  ],
                  onChanged: (v) => onCountry(v ?? code),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: city,
            decoration: const InputDecoration(labelText: 'City (optional)'),
          ),
        ),
      ],
    );
  }

  Widget _dateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime> onPick,
  ) {
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
