import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/hero_image.dart';
import '../../../ui/image_picker_field.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/star_rating.dart';
import '../../../ui/status_pill.dart';
import '../../../ui/stock_images.dart';
import '../../auth/application/auth_controller.dart';
import '../data/orders_repository.dart';
import '../domain/order.dart';
import 'order_stepper.dart';
import 'report_problem_sheet.dart';
import 'trust_panel.dart';

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${orderId.substring(0, 8).toUpperCase()}'),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/my-wants'),
        ),
      ),
      body: AsyncValueView(
        value: order,
        onRetry: () => ref.invalidate(orderProvider(orderId)),
        data: (o) {
          final isShopper = me?.id == o.shopperId;
          final active = o.status != 'delivered' && o.status != 'cancelled';
          return RefreshIndicator(
            onRefresh: () => ref.pullToRefresh(orderProvider(orderId).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 76,
                        height: 76,
                        child: HeroImage(
                          url: o.requestImageUrl,
                          fallbackAsset: stockForCategory(o.requestCategory),
                          height: 76,
                          borderRadius: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.itemDescription,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Row(children: [
                            StatusPill(o.status),
                            const SizedBox(width: 8),
                            Text('${o.totalLabel} · ${o.feesLabel} fee',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (o.counterparty != null)
                  SoftCard(
                    child: Row(
                      children: [
                        Expanded(child: AvatarRating(user: o.counterparty!)),
                        Text(isShopper ? 'Carrier' : 'Shopper',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                SoftCard(child: OrderStepper(order: o)),
                if (o.purchaseProofUrl != null) ...[
                  const SizedBox(height: 14),
                  _ReceiptCard(url: o.purchaseProofUrl!, at: o.purchasedAt),
                ],
                const SizedBox(height: 14),
                TrustPanel(order: o),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/orders/$orderId/chat'),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Open chat'),
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showReportProblemSheet(context, orderId),
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: const Text('Report'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                _ActionBlock(order: o, isShopper: isShopper),
              ],
            ),
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
      ref.invalidate(myOrdersProvider);
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

    Widget note(String t) => Text(t, style: muted);
    Widget primary(String label, VoidCallback? onTap) => FilledButton(
          onPressed: _busy ? null : onTap,
          child: _busy
              ? const SizedBox(
                  height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(label),
        );

    switch (o.status) {
      case 'pending_payment':
        if (!widget.isShopper) return note('Waiting for the shopper to pay.');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How to pay', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(me?.pilot?.paymentInstructions ??
                    'Contact the Hiww team to arrange payment.'),
                const SizedBox(height: 6),
                Text('Amount ${o.totalLabel}  ·  reference ${o.id}', style: muted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (o.paymentClaimedAt != null)
            note("You've told us you paid. We'll confirm once it lands.")
          else
            primary("I've sent the payment", () => _run(() => repo.claimPayment(o.id))),
        ]);
      case 'confirmed':
        if (widget.isShopper) {
          return note('Payment confirmed. Waiting for the traveler to buy the item.');
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          note('Payment confirmed. Buy the item, then upload a photo of the shop '
              'receipt — clear date and the item in frame. That unlocks the '
              'shipping step.'),
          const SizedBox(height: 12),
          ImagePickerField(
            value: null,
            label: _busy ? 'Uploading…' : 'Upload purchase receipt',
            onChanged: (url) {
              if (url != null) _run(() => repo.submitPurchaseProof(o.id, url));
            },
          ),
        ]);
      case 'purchased':
        if (widget.isShopper) {
          return note('The traveler bought your item. They’ll ship it once '
              'they’re back in the origin country.');
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          note('Receipt uploaded. Post the item when you’re home, then mark it shipped.'),
          const SizedBox(height: 12),
          primary('Mark as shipped', () => _run(() => repo.markShipped(o.id))),
        ]);
      case 'in_transit':
        if (!widget.isShopper) {
          return note('Shipped. Waiting for the shopper to confirm receipt.');
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          note('On the way. Confirm once you have it in hand.'),
          const SizedBox(height: 12),
          primary('Confirm & release ${o.totalLabel}',
              () => context.push('/orders/${o.id}/confirm')),
        ]);
      case 'delivered':
        if (o.myReview != null) {
          return Row(children: [
            Text('You rated ', style: muted),
            StarRatingDisplay(rating: o.myReview!.rating.toDouble(), size: 13),
          ]);
        }
        if (o.canReview) {
          return primary('Rate ${o.counterparty?.fullName ?? 'the other party'}',
              () => context.push('/orders/${o.id}/confirm?review=1'));
        }
        return note('Completed. Thanks for using Hiww!');
      default:
        return note('This order is ${o.status.replaceAll('_', ' ')}.');
    }
  }
}

/// Shop receipt the traveler uploaded as proof of purchase. Visible to both
/// parties and the operator; tap to view full-screen.
class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.url, this.at});
  final String url;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.receipt_long_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text('Purchase receipt', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (at != null)
              Text(shortDate(at),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.black,
                insetPadding: const EdgeInsets.all(12),
                child: InteractiveViewer(
                  child: HeroImage(
                    url: url,
                    fallbackAsset: 'assets/images/electronics.jpg',
                    height: 480,
                    borderRadius: 0,
                  ),
                ),
              ),
            ),
            child: HeroImage(
              url: url,
              fallbackAsset: 'assets/images/electronics.jpg',
              height: 150,
              borderRadius: 12,
            ),
          ),
        ],
      ),
    );
  }
}
