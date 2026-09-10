import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/countries.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/busy_filled_button.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/soft_card.dart';
import '../../trips/data/trips_repository.dart';
import '../../trips/domain/trip.dart';
import '../../trips/presentation/add_trip_sheet.dart';
import '../data/offers_repository.dart';
import '../data/wants_repository.dart';
import '../domain/want.dart';

/// A full-screen push route, not a bottom sheet — reached by drilling into
/// an existing want, and it's a single price field, so it doesn't need the
/// sheet-with-Summary-review treatment the two "create from scratch via FAB"
/// flows use (`create_order_sheet.dart`, `add_trip_sheet.dart`).
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
  bool _pricePrefilled = false;
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
    final trips = ref.read(myPublishedTripsProvider).valueOrNull ?? const <Trip>[];
    final trip = trips.where((t) => t.id == _tripId).firstOrNull;
    if (trip?.returnDate != null && _deliverBy!.isBefore(trip!.returnDate!)) {
      setState(() => _error = l10n.errorDeliveryBeforeReturn);
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
    final want = ref.watch(wantDetailProvider(widget.wantId)).valueOrNull?.want;
    // Default to what the shopper already said they'd pay — the traveler can
    // still change it, but starting from their budget is a better anchor
    // than a blank field.
    if (want != null && !_pricePrefilled) {
      _pricePrefilled = true;
      _price.text = want.budget;
    }

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
                onPressed: () => showAddTripSheet(context),
                child: Text(l10n.actionPostATrip),
              ),
            );
          }
          _tripId ??= list.first.id;
          final selectedTrip = list.where((t) => t.id == _tripId).firstOrNull ?? list.first;
          final now = DateTime.now();
          final minDeliverBy = (selectedTrip.returnDate != null && selectedTrip.returnDate!.isAfter(now))
              ? selectedTrip.returnDate!
              : now;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Buy-in and deliver-to cities, shown up front so the price
              // typed below can actually account for courier cost.
              if (want != null) ...[
                _WantContextCard(want: want),
                const SizedBox(height: 16),
              ],
              Text(l10n.labelWhichTrip, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _tripId,
                isExpanded: true,
                items: [
                  for (final t in list)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text(
                        '${t.route}  ·  ${t.dates}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _tripId = v;
                    final newTrip = list.firstWhere((t) => t.id == v);
                    if (newTrip.returnDate != null &&
                        _deliverBy != null &&
                        _deliverBy!.isBefore(newTrip.returnDate!)) {
                      _deliverBy = null;
                    }
                  });
                },
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
              const SizedBox(height: 4),
              Text(
                l10n.hintDeliverByFromReturn(shortDate(minDeliverBy)),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final initial = (_deliverBy != null && !_deliverBy!.isBefore(minDeliverBy))
                      ? _deliverBy!
                      : minDeliverBy;
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: minDeliverBy,
                    lastDate: minDeliverBy.add(const Duration(days: 365)),
                    initialDate: initial,
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
              BusyFilledButton(
                busy: _submitting,
                label: l10n.actionSendOffer,
                onPressed: _submit,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The want's buy-in and deliver-to locations, so a traveler can factor
/// courier/delivery cost into the price they're about to type below.
class _WantContextCard extends StatelessWidget {
  const _WantContextCard({required this.want});
  final Want want;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            want.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            IconLine(Icons.public, l10n.wantBuyInLine(want.sourceCity ?? countryName(want.sourceCountry))),
            if (want.destinationLabel != null)
              IconLine(Icons.local_shipping_outlined, l10n.wantDeliverToLine(want.destinationLabel!)),
          ]),
        ],
      ),
    );
  }
}
