import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final priceNum = double.tryParse(_price.text.trim());
    if (_tripId == null) {
      setState(() => _error = l10n.errorPickTripForOffer);
      return;
    }
    if (priceNum == null || priceNum <= 0) {
      setState(() => _error = l10n.errorEnterYourPrice);
      return;
    }
    if (_deliverBy == null) {
      setState(() => _error = l10n.errorPickDeliveryDate);
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
      ref.invalidate(negotiationsProvider);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.infoOfferSent)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
      if (e.code == 'PROFILE_INCOMPLETE') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          action: SnackBarAction(label: l10n.actionAddDetails, onPressed: () => context.push('/account')),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final trips = ref.watch(myPublishedTripsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.makeOfferTitle)),
      body: AsyncValueView(
        value: trips,
        onRetry: () => ref.invalidate(myPublishedTripsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.flight_outlined,
              title: l10n.emptyNeedTripTitle,
              message: l10n.emptyNeedTripMessage,
              action: FilledButton(
                onPressed: () => context.push('/trips/new'),
                child: Text(l10n.actionPostATrip),
              ),
            );
          }
          _tripId ??= list.first.id;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.labelWhichTrip, style: Theme.of(context).textTheme.labelLarge),
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
                decoration: InputDecoration(
                  labelText: l10n.fieldYourPriceForGoods,
                  prefixText: '฿ ',
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.labelDeliverBy, style: Theme.of(context).textTheme.labelLarge),
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
                label: Text(_deliverBy == null ? l10n.actionPickADate : shortDate(_deliverBy)),
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
                    : Text(l10n.actionSendOffer),
              ),
            ],
          );
        },
      ),
    );
  }
}
