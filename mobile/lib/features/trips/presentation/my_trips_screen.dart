import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/async_value_view.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/status_pill.dart';
import '../../wants/data/offers_repository.dart';
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
      onRefresh: () async => ref.invalidate(myTripsProvider),
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
      onRefresh: () async => ref.invalidate(myOffersProvider),
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
              return SoftCard(
                onTap: o.requestId == null
                    ? null
                    : () => context.push('/wants/${o.requestId}'),
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
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      if (o.deliveryLabel != null) ...[
                        const SizedBox(width: 12),
                        Text(o.deliveryLabel!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 13)),
                      ],
                    ]),
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
