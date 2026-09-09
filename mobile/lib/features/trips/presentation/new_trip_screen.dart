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
import '../domain/trip.dart';

/// Editing an existing trip is a full-screen form. Posting a new trip is a
/// separate, simpler bottom sheet — see `add_trip_sheet.dart`'s
/// `showAddTripSheet`. Route (departure/arrival country) is never editable —
/// see the schema-side comment for why.
class EditTripScreen extends ConsumerStatefulWidget {
  const EditTripScreen({super.key, required this.existing});
  final Trip existing;

  @override
  ConsumerState<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends ConsumerState<EditTripScreen> {
  late final _fromCity = TextEditingController(text: widget.existing.departureCity ?? '');
  late final _toCity = TextEditingController(text: widget.existing.arrivalCity ?? '');
  late final _note = TextEditingController(text: widget.existing.note ?? '');
  late final _weight = TextEditingController(text: widget.existing.maxWeightKg.toString());
  late final _items = TextEditingController(text: widget.existing.maxItems.toString());
  late String? _coverUrl = widget.existing.coverImageUrl;
  late DateTime? _depart = widget.existing.departureDate;
  late DateTime? _ret = widget.existing.returnDate;
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
      final id = widget.existing.id;
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
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  /// A single "Cancel trip" action for the user — whether that ends up being
  /// a real delete (no offers yet) or a status change (some interest
  /// already) is an implementation detail they shouldn't have to reason
  /// about. Tries the real delete first and silently falls back to cancel
  /// when offers exist; if an order is actually in progress, neither is
  /// appropriate — that's resolved per-order via "Report a problem", not
  /// here, since one trip can carry many shoppers' orders.
  Future<void> _cancelTrip() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dialogCancelTripTitle),
        content: Text(l10n.dialogCancelTripBody),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: Text(l10n.actionKeepTrip)),
          FilledButton(
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.actionCancelTrip),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    final id = widget.existing.id;
    final repo = ref.read(tripsRepositoryProvider);

    try {
      await repo.delete(id);
    } on ApiException catch (e) {
      if (e.code != 'TRIP_HAS_OFFERS') {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _error = e.message;
        });
        return;
      }
      try {
        await repo.cancel(id);
      } on ApiException catch (e2) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _error = e2.code == 'TRIP_HAS_ACTIVE_ORDERS'
              ? l10n.errorTripHasActiveOrder
              : e2.message;
        });
        return;
      }
    }

    ref.invalidate(myTripsProvider);
    ref.invalidate(feedProvider);
    ref.invalidate(tripDetailProvider(id));
    if (!mounted) return;
    context.pop();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tripEditTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.actionCancelTrip,
            onPressed: _submitting ? null : _cancelTrip,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _countryRow(l10n.labelFrom, widget.existing.departureCountry, _fromCity),
          const SizedBox(height: 14),
          _countryRow(l10n.labelTo, widget.existing.arrivalCountry, _toCity),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _dateField(
                  l10n.labelDeparture,
                  _depart,
                  (d) => setState(() => _depart = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dateField(
                  l10n.labelReturn,
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
                  decoration: InputDecoration(
                    labelText: l10n.fieldSpareWeightKg,
                  ),
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
                : Text(l10n.actionSaveChanges),
          ),
        ],
      ),
    );
  }

  Widget _countryRow(String label, String code, TextEditingController city) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: countryName(code),
            enabled: false,
            decoration: InputDecoration(labelText: label),
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
