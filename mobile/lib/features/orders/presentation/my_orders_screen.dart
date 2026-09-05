import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/async_value_view.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/hero_image.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/status_pill.dart';
import '../../../ui/stock_images.dart';
import '../../auth/application/auth_controller.dart';
import '../data/orders_repository.dart';
import '../domain/order.dart';

/// One place to see every order the signed-in user is part of — as a shopper
/// buying, or a traveler delivering — with the current stage and what happens
/// next. Tapping opens the full order tracker.
class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.pullToRefresh(myOrdersProvider.future),
        child: AsyncValueView(
          value: orders,
          onRetry: () => ref.invalidate(myOrdersProvider),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders yet',
                  message:
                      'When you accept an offer or one of your offers is accepted, '
                      'the order shows up here so you can track every step.',
                ),
              ]);
            }

            final sorted = [...list]..sort((a, b) {
              final byActive = _rank(a).compareTo(_rank(b));
              if (byActive != 0) return byActive;
              final ad = a.createdAt ?? DateTime(0);
              final bd = b.createdAt ?? DateTime(0);
              return bd.compareTo(ad);
            });

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final o = sorted[i];
                final isShopper = me?.id == o.shopperId;
                return _OrderCard(order: o, isShopper: isShopper);
              },
            );
          },
        ),
      ),
    );
  }

  /// Active orders first, finished ones last.
  static int _rank(Order o) =>
      (o.status == 'delivered' || o.status == 'cancelled') ? 1 : 0;
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.isShopper});

  final Order order;
  final bool isShopper;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final o = order;
    final who = o.counterparty?.fullName ?? (isShopper ? 'a traveler' : 'a shopper');
    final relation = isShopper ? 'Buying from $who' : 'Delivering for $who';
    final next = _nextStep(o.status, isShopper);

    return SoftCard(
      onTap: () => context.push('/orders/${o.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: HeroImage(
                url: o.requestImageUrl,
                fallbackAsset: stockForCategory(o.requestCategory),
                height: 56,
                borderRadius: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.itemDescription,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(relation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(children: [
                  StatusPill(o.status),
                  const SizedBox(width: 8),
                  Text(o.totalLabel,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ]),
                if (next != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.arrow_forward, size: 13, color: scheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(next,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary)),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Plain-language "what happens next", from this user's point of view.
  static String? _nextStep(String status, bool isShopper) => switch (status) {
        'pending_payment' => isShopper
            ? 'Pay to get things moving'
            : 'Waiting for the shopper to pay',
        'confirmed' => isShopper
            ? 'Traveler is buying and shipping your item'
            : 'Buy the item, ship it, then mark it shipped',
        'in_transit' => isShopper
            ? 'On its way — confirm when it arrives'
            : 'Shipped — waiting for the shopper to confirm receipt',
        'delivered' => null,
        'cancelled' => null,
        _ => null,
      };
}
