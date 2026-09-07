import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/async_value_view.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/initials_avatar.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/status_pill.dart';
import '../../orders/data/orders_repository.dart';
import '../data/offers_repository.dart';
import '../domain/offer.dart';
import 'offer_negotiation_actions.dart';

/// Every negotiation the signed-in user is part of, on either side — as a
/// traveler who made an offer, or a shopper who owns the want it's on.
/// Replaces having to dig through My Trips > Offers or each want's own
/// detail page separately.
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final negotiations = ref.watch(negotiationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: RefreshIndicator(
        onRefresh: () => ref.pullToRefresh(negotiationsProvider.future),
        child: AsyncValueView(
          value: negotiations,
          onRetry: () => ref.invalidate(negotiationsProvider),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 70),
                EmptyState(
                  icon: Icons.handshake_outlined,
                  title: 'No offers yet',
                  message: 'Offers you make or receive — as a shopper or a traveler — show up here.',
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _NegotiationCard(offer: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _NegotiationCard extends ConsumerStatefulWidget {
  const _NegotiationCard({required this.offer});
  final Offer offer;

  @override
  ConsumerState<_NegotiationCard> createState() => _NegotiationCardState();
}

class _NegotiationCardState extends ConsumerState<_NegotiationCard> {
  Future<void> _refresh() async {
    ref.invalidate(negotiationsProvider);
  }

  Future<void> _accept() async {
    final orderId = await ref.read(offersRepositoryProvider).accept(widget.offer.id);
    await _refresh();
    ref.invalidate(myOrdersProvider);
    if (mounted) context.push('/orders/$orderId');
  }

  Future<void> _counter(String price) async {
    await ref.read(offersRepositoryProvider).counter(widget.offer.id, price);
    await _refresh();
  }

  Future<void> _reject() async {
    await ref.read(offersRepositoryProvider).reject(widget.offer.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    final iAmShopper = o.myRole == 'shopper';
    return SoftCard(
      onTap: o.requestId == null ? null : () => context.push('/wants/${o.requestId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: o.counterpartyName ?? '?', radius: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.requestItem ?? 'Offer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      iAmShopper ? 'From ${o.counterpartyName ?? 'a traveler'}' : 'To ${o.counterpartyName ?? 'a shopper'}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              StatusPill(o.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(o.priceLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          if (o.isNegotiating) ...[
            const SizedBox(height: 4),
            Text(
              'Countered ${o.round} time${o.round == 1 ? '' : 's'}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
          if (o.status == 'pending') ...[
            const SizedBox(height: 12),
            OfferNegotiationActions(
              offer: o,
              enabled: o.requestStatus == 'open',
              onAccept: _accept,
              onCounter: _counter,
              onReject: _reject,
            ),
          ],
        ],
      ),
    );
  }
}
