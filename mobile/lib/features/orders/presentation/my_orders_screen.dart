import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
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
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: l10n.emptyOrdersTitle,
                  message: l10n.emptyOrdersMessage,
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
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final o = order;
    final who = o.counterparty?.fullName ?? (isShopper ? l10n.fallbackATraveler : l10n.fallbackAShopper);
    final relation = isShopper ? l10n.orderRelationBuying(who) : l10n.orderRelationDelivering(who);
    final next = _nextStep(l10n, o.status, isShopper);

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
  static String? _nextStep(AppLocalizations l10n, String status, bool isShopper) => switch (status) {
        'pending_payment' => isShopper
            ? l10n.nextStepPayToStart
            : l10n.nextStepWaitingForPayment,
        'confirmed' => isShopper
            ? l10n.nextStepTravelerBuying
            : l10n.nextStepBuyThenUpload,
        'purchased' => isShopper
            ? l10n.nextStepBoughtWaitShip
            : l10n.nextStepPostThenShip,
        'in_transit' => isShopper
            ? l10n.nextStepOnWayConfirm
            : l10n.nextStepShippedWaiting,
        'delivered' => null,
        'cancelled' => null,
        _ => null,
      };
}
