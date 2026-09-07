import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/empty_state.dart';
import '../../trips/data/trips_repository.dart';
import '../data/offers_repository.dart';
import '../data/wants_repository.dart';

class MakeOfferScreen extends ConsumerStatefulWidget {
  const MakeOfferScreen({super.key, required this.wantId});
  final String wantId;

  @override
  ConsumerState<MakeOfferScreen> createState() => _MakeOfferScreenState();
}

class _MakeOfferScreenState extends ConsumerState<MakeOfferScreen> {
  final _price = TextEditingController();
  String? _tripId;
  DateTime? _deliverBy;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final priceNum = double.tryParse(_price.text.trim());
    if (_tripId == null) {
      setState(() => _error = 'Pick which trip this is for');
      return;
    }
    if (priceNum == null || priceNum <= 0) {
      setState(() => _error = 'Enter your price');
      return;
    }
    if (_deliverBy == null) {
      setState(() => _error = 'Pick a delivery date');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(offersRepositoryProvider).create(
            requestId: widget.wantId,
            tripId: _tripId!,
            quotedPrice: priceNum.toStringAsFixed(2),
            deliveryDate: _deliverBy!,
          );
      ref.invalidate(wantOffersProvider(widget.wantId));
      ref.invalidate(myOffersProvider);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Offer sent')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
      if (e.code == 'PROFILE_INCOMPLETE') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          action: SnackBarAction(label: 'Update profile', onPressed: () => context.push('/account')),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(myPublishedTripsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Make an offer')),
      body: AsyncValueView(
        value: trips,
        onRetry: () => ref.invalidate(myPublishedTripsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.flight_outlined,
              title: 'You need a trip first',
              message: 'Post a trip you can carry this item on, then make your offer.',
              action: FilledButton(
                onPressed: () => context.push('/trips/new'),
                child: const Text('Post a trip'),
              ),
            );
          }
          _tripId ??= list.first.id;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Which trip', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _tripId,
                items: [
                  for (final t in list)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.route}  ·  ${t.dates}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _tripId = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Your price for the goods',
                  prefixText: '฿ ',
                ),
              ),
              const SizedBox(height: 16),
              Text('Deliver by', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                    initialDate: _deliverBy ?? now.add(const Duration(days: 21)),
                  );
                  if (picked != null) setState(() => _deliverBy = picked);
                },
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(_deliverBy == null ? 'Pick a date' : shortDate(_deliverBy)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Send offer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
