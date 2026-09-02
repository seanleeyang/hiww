import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../theme/app_colors.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/status_pill.dart';
import '../../auth/application/auth_controller.dart';
import '../data/orders_repository.dart';
import '../domain/order.dart';

/// D3 order view — status + the manual-money action for the current stage.
/// D4 replaces this with the full dated tracker + review flow.
class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order'),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/my-wants')),
      ),
      body: AsyncValueView(
        value: order,
        onRetry: () => ref.invalidate(orderProvider(orderId)),
        data: (o) {
          final isShopper = me?.id == o.shopperId;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(o.itemDescription,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  StatusPill(o.status),
                ],
              ),
              const SizedBox(height: 12),
              if (o.counterparty != null)
                AvatarRating(user: o.counterparty!, radius: 18),
              const SizedBox(height: 16),
              SoftCard(
                color: context.hiww.infoSurface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.lock_outline, size: 18),
                      const SizedBox(width: 8),
                      Text('Hiww is holding ${o.totalLabel} + ${o.feesLabel} fee',
                          style: Theme.of(context).textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'Released to the traveler when you confirm delivery. During '
                      'the pilot, payments are settled by the Hiww team.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ActionBlock(order: o, isShopper: isShopper),
            ],
          );
        },
      ),
    );
  }
}

class _ActionBlock extends ConsumerStatefulWidget {
  const _ActionBlock({required this.order, required this.isShopper});
  final Order order;
  final bool isShopper;

  @override
  ConsumerState<_ActionBlock> createState() => _ActionBlockState();
}

class _ActionBlockState extends ConsumerState<_ActionBlock> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(orderProvider(widget.order.id));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final repo = ref.read(ordersRepositoryProvider);
    final me = ref.read(currentUserProvider);
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);

    Widget note(String text) => Text(text, style: muted);
    Widget button(String label, Future<void> Function() action) => FilledButton(
          onPressed: _busy ? null : () => _run(action),
          child: _busy
              ? const SizedBox(
                  height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(label),
        );

    switch (o.status) {
      case 'pending_payment':
        if (!widget.isShopper) return note('Waiting for the shopper to pay.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How to pay', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(me?.pilot?.paymentInstructions ??
                      'Contact the Hiww team to arrange payment.'),
                  const SizedBox(height: 6),
                  Text('Amount ${o.totalLabel} · reference ${o.id}',
                      style: muted),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (o.paymentClaimedAt != null)
              note("You've told us you paid. We'll confirm once it lands.")
            else
              button("I've sent the payment", () => repo.claimPayment(o.id)),
          ],
        );
      case 'confirmed':
        if (widget.isShopper) {
          return note('Payment received. Waiting for the traveler to buy and ship.');
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          note('Payment received. Buy the item, ship it, then mark it shipped.'),
          const SizedBox(height: 12),
          button('Mark as shipped', () => repo.markShipped(o.id)),
        ]);
      case 'in_transit':
        if (!widget.isShopper) return note('Shipped. Waiting for the shopper to confirm receipt.');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          note('On the way. Confirm once you have it in hand.'),
          const SizedBox(height: 12),
          button('Confirm I received it', () => repo.confirmReceived(o.id)),
        ]);
      case 'delivered':
        return note('Completed. Thanks for using Hiww!');
      default:
        return note('This order is ${o.status.replaceAll('_', ' ')}.');
    }
  }
}
