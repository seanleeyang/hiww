import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/breakdown_row.dart';
import '../../../ui/hero_image.dart';
import '../../../ui/image_picker_field.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/responsive_body.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final order = ref.watch(orderProvider(orderId));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orderHashTitle(orderId.substring(0, 8).toUpperCase())),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/my-orders'),
        ),
      ),
      body: ResponsiveBody(
        child: AsyncValueView(
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
                            enableFullscreen: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.itemDescription,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                StatusPill(o.status),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.orderTotalWithFee(o.totalLabel, o.feesLabel),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
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
                          Text(
                            isShopper ? l10n.roleCarrier : l10n.roleShopper,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
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
                  if (o.hasPricingBreakdown) ...[
                    const SizedBox(height: 14),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: isShopper
                            ? [
                                BreakdownRow(l10n.priceBreakdownProductPrice, o.totalLabel),
                                BreakdownRow(l10n.priceBreakdownTravellerReward, o.travellerRewardLabel!),
                                BreakdownRow(l10n.priceBreakdownServiceFee, o.feesLabel),
                                const Divider(height: 16),
                                BreakdownRow(l10n.priceBreakdownTotal, o.shopperTotalLabel!, bold: true),
                              ]
                            : [
                                BreakdownRow(l10n.travellerBreakdownProductValue, o.totalLabel),
                                BreakdownRow(l10n.travellerBreakdownYourReward, o.travellerRewardLabel!),
                                const Divider(height: 16),
                                BreakdownRow(l10n.travellerBreakdownYouReceive, o.travellerPayoutLabel!, bold: true),
                              ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/orders/$orderId/chat'),
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: Text(l10n.actionOpenChat),
                        ),
                      ),
                      if (active) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                showReportProblemSheet(context, orderId),
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: Text(l10n.actionReport),
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
    final l10n = AppLocalizations.of(context)!;
    final o = widget.order;
    final repo = ref.read(ordersRepositoryProvider);
    final me = ref.read(currentUserProvider);
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    Widget note(String t) => Text(t, style: muted);
    Widget primary(String label, VoidCallback? onTap) => FilledButton(
      onPressed: _busy ? null : onTap,
      child: _busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );

    switch (o.status) {
      case 'pending_payment':
        final showCountdown = o.paymentDeadlineAt != null && o.paymentClaimedAt == null;
        if (!widget.isShopper) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showCountdown) ...[
                _PaymentCountdownBanner(orderId: o.id, deadline: o.paymentDeadlineAt!, forShopper: false),
                const SizedBox(height: 12),
              ],
              note(l10n.noteWaitingForShopperToPay),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showCountdown) ...[
              _PaymentCountdownBanner(orderId: o.id, deadline: o.paymentDeadlineAt!, forShopper: true),
              const SizedBox(height: 12),
            ],
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.howToPayTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    me?.pilot?.paymentInstructions ??
                        l10n.contactHiwwForPayment,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.amountReference(o.totalLabel, o.id),
                    style: muted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (o.paymentClaimedAt != null)
              note(l10n.noteToldUsPaid)
            else
              primary(
                l10n.actionSentPayment,
                () => _run(() => repo.claimPayment(o.id)),
              ),
          ],
        );
      case 'confirmed':
        if (widget.isShopper) {
          return note(l10n.notePaymentConfirmedWaitingBuy);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            note(l10n.notePaymentConfirmedUploadReceipt),
            const SizedBox(height: 12),
            ImagePickerField(
              value: null,
              label: _busy ? l10n.actionUploading : l10n.actionUploadReceipt,
              onChanged: (url) {
                if (url != null) {
                  _run(() => repo.submitPurchaseProof(o.id, url));
                }
              },
            ),
          ],
        );
      case 'purchased':
        if (widget.isShopper) {
          return note(l10n.noteTravelerBoughtWillShip);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            note(l10n.noteReceiptUploadedPostShip),
            const SizedBox(height: 12),
            primary(
              l10n.actionMarkShipped,
              () => _run(() => repo.markShipped(o.id)),
            ),
          ],
        );
      case 'in_transit':
        if (!widget.isShopper) {
          return note(l10n.noteShippedWaitingConfirm);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            note(l10n.noteOnWayConfirm),
            const SizedBox(height: 12),
            primary(
              l10n.actionConfirmRelease(o.totalLabel),
              () => context.push('/orders/${o.id}/confirm'),
            ),
          ],
        );
      case 'delivered':
        if (o.myReview != null) {
          return Row(
            children: [
              Text('${l10n.ratedLabel} ', style: muted),
              StarRatingDisplay(
                rating: o.myReview!.rating.toDouble(),
                size: 13,
              ),
            ],
          );
        }
        if (o.canReview) {
          return primary(
            l10n.actionRateCounterparty(o.counterparty?.fullName ?? l10n.fallbackTheOtherParty),
            () => context.push('/orders/${o.id}/confirm?review=1'),
          );
        }
        return note(l10n.noteCompletedThanks);
      default:
        return note(l10n.orderStatusFallback(o.status.replaceAll('_', ' ')));
    }
  }
}

/// A ticking "pay within Xh Xm" banner shown while an order awaits payment.
/// Purely visual on a timer — the actual cancellation only ever happens
/// server-side (see `src/services/order-expiry.ts`), so once the countdown
/// hits zero this just refreshes the order once to pick up the real status.
class _PaymentCountdownBanner extends ConsumerStatefulWidget {
  const _PaymentCountdownBanner({
    required this.orderId,
    required this.deadline,
    required this.forShopper,
  });
  final String orderId;
  final DateTime deadline;
  final bool forShopper;

  @override
  ConsumerState<_PaymentCountdownBanner> createState() => _PaymentCountdownBannerState();
}

class _PaymentCountdownBannerState extends ConsumerState<_PaymentCountdownBanner> {
  Timer? _timer;
  bool _refreshedOnExpiry = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (DateTime.now().isAfter(widget.deadline) && !_refreshedOnExpiry) {
        _refreshedOnExpiry = true;
        ref.invalidate(orderProvider(widget.orderId));
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final urgent = widget.deadline.difference(DateTime.now()).inMinutes < 15;
    final scheme = Theme.of(context).colorScheme;
    final fg = urgent ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    final label = widget.forShopper
        ? l10n.payWithinOrCancel(countdown(widget.deadline))
        : l10n.shopperHasTimeToPay(countdown(widget.deadline));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: urgent ? scheme.errorContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: fg, fontSize: 13))),
        ],
      ),
    );
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
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.purchaseReceiptTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if (at != null)
                Text(
                  shortDate(at),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          HeroImage(
            url: url,
            fallbackAsset: 'assets/images/electronics.jpg',
            height: 150,
            borderRadius: 12,
            enableFullscreen: true,
          ),
        ],
      ),
    );
  }
}
