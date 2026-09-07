import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/async_value_view.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/status_pill.dart';
import '../../orders/data/orders_repository.dart';
import '../../wants/data/offers_repository.dart';
import '../../wants/domain/offer.dart';
import '../../wants/presentation/offer_negotiation_actions.dart';
import '../data/trips_repository.dart';

class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/trips/new'),
          icon: const Icon(Icons.add),
          label: const Text('Post a trip'),
        ),
        body: Column(
          children: [
            const TabBar(tabs: [Tab(text: 'Trips'), Tab(text: 'Offers')]),
            Expanded(
              child: TabBarView(
                children: [
                  _TripsTab(),
                  _OffersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(myTripsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.pullToRefresh(myTripsProvider.future),
      child: AsyncValueView(
        value: trips,
        onRetry: () => ref.invalidate(myTripsProvider),
        data: (list) {
          if (list.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 70),
              EmptyState(
                icon: Icons.flight_outlined,
                title: 'No trips yet',
                message: 'Post a trip and shoppers can request items along your route.',
                action: FilledButton(
                  onPressed: () => context.push('/trips/new'),
                  child: const Text('Post a trip'),
                ),
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final t = list[i];
              return SoftCard(
                onTap: () => context.push('/trips/${t.id}'),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title ?? t.route,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 6),
                          RouteChip(route: t.route, dates: t.dates),
                        ],
                      ),
                    ),
                    StatusPill(t.status),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _OffersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(myOffersProvider);
    return RefreshIndicator(
      onRefresh: () => ref.pullToRefresh(myOffersProvider.future),
      child: AsyncValueView(
        value: offers,
        onRetry: () => ref.invalidate(myOffersProvider),
        data: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 70),
              EmptyState(
                icon: Icons.local_offer_outlined,
                title: 'No offers yet',
                message: 'Browse wants and make an offer against one of your trips.',
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final o = list[i];
              final orderId = ref.watch(orderIdByRequestProvider).maybeWhen(
                  data: (m) => o.requestId == null ? null : m[o.requestId],
                  orElse: () => null);
              return _TravelerOfferCard(offer: o, orderId: orderId);
            },
          );
        },
      ),
    );
  }
}

class _TravelerOfferCard extends ConsumerStatefulWidget {
  const _TravelerOfferCard({required this.offer, required this.orderId});
  final Offer offer;
  final String? orderId;

  @override
  ConsumerState<_TravelerOfferCard> createState() => _TravelerOfferCardState();
}

class _TravelerOfferCardState extends ConsumerState<_TravelerOfferCard> {
  Future<void> _refresh() async {
    ref.invalidate(myOffersProvider);
  }

  Future<void> _accept() async {
    final orderId = await ref.read(offersRepositoryProvider).accept(widget.offer.id);
    await _refresh();
    ref.invalidate(myOrdersProvider);
    if (mounted) context.go('/orders/$orderId');
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
    final canOpen = widget.orderId != null || o.requestId != null;
    return SoftCard(
      onTap: !canOpen
          ? null
          : () => widget.orderId != null
              ? context.push('/orders/${widget.orderId}')
              : context.push('/wants/${o.requestId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(o.requestItem ?? 'Offer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              StatusPill(o.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            Text(o.priceLabel,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (o.deliveryLabel != null) ...[
              const SizedBox(width: 12),
              Text(o.deliveryLabel!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13)),
            ],
          ]),
          if (o.isNegotiating) ...[
            const SizedBox(height: 4),
            Text(
              'Countered ${o.round} time${o.round == 1 ? '' : 's'}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
          if (o.status == 'pending' && widget.orderId == null) ...[
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
