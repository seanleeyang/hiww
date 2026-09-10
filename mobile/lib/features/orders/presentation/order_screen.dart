import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/breakdown_row.dart';
import '../../../ui/busy_filled_button.dart';
import '../../../ui/confirm_dialog.dart';
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
                    _PurchaseProofCard(
                      receiptUrl: o.purchaseProofUrl!,
                      itemPhotoUrl: o.itemPhotoUrl,
                      at: o.purchasedAt,
                    ),
                  ],
                  if (o.shippingProofUrl != null) ...[
                    const SizedBox(height: 14),
                    _ShippingProofCard(url: o.shippingProofUrl!, at: o.shippedAt),
                  ],
                  if (o.deliveryProofUrl != null) ...[
                    const SizedBox(height: 14),
                    _DeliveryProofCard(url: o.deliveryProofUrl!, at: o.deliveredAt),
                  ],
                  const SizedBox(height: 14),
                  TrustPanel(order: o, isShopper: isShopper),
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
  String? _itemPhotoUrl;
  String? _receiptUrl;
  String? _shippingProofUrl;
  String? _deliveryProofUrl;

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

  /// The single highest-stakes tap in the app — it irreversibly releases
  /// escrowed payment — so it gets the same "are you sure" every other
  /// destructive/committing action in the app gets, unlike before.
  Future<void> _confirmRelease(String orderId, String totalLabel, String imageUrl) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.dialogReleasePaymentTitle(totalLabel),
      body: Text(l10n.dialogReleasePaymentBody),
      confirmLabel: l10n.actionRelease,
      cancelLabel: l10n.actionCancel,
    );
    if (!ok || !mounted) return;
    await _confirmAndReview(orderId, imageUrl);
  }

  /// Releases payment, then moves straight on to leaving a review — the
  /// photo above is the only thing gating release, so there's nothing left
  /// to confirm on the next screen.
  Future<void> _confirmAndReview(String orderId, String imageUrl) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await ref.read(ordersRepositoryProvider).confirmReceived(orderId, imageUrl: imageUrl);
      ref.invalidate(orderProvider(orderId));
      ref.invalidate(myOrdersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.infoPaymentReleased)));
      context.push('/orders/$orderId/confirm');
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
    Widget primary(String label, VoidCallback? onTap) =>
        BusyFilledButton(busy: _busy, label: label, onPressed: onTap);

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
            const _PromptPayQrPlaceholder(),
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
        final canSubmitProof = _itemPhotoUrl != null && _receiptUrl != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            note(l10n.notePaymentConfirmedUploadReceipt),
            if (o.daysLeftToUpload != null) ...[
              const SizedBox(height: 12),
              _UploadDeadlineBanner(daysLeft: o.daysLeftToUpload!),
            ],
            const SizedBox(height: 12),
            ImagePickerField(
              value: _itemPhotoUrl,
              label: _busy ? l10n.actionUploading : l10n.actionUploadItemPhoto,
              onChanged: (url) => setState(() => _itemPhotoUrl = url),
            ),
            const SizedBox(height: 12),
            ImagePickerField(
              value: _receiptUrl,
              label: _busy ? l10n.actionUploading : l10n.actionUploadReceipt,
              onChanged: (url) => setState(() => _receiptUrl = url),
            ),
            const SizedBox(height: 12),
            primary(
              l10n.actionSubmitPurchaseProof,
              canSubmitProof
                  ? () => _run(() => repo.submitPurchaseProof(
                        o.id,
                        receiptImageUrl: _receiptUrl!,
                        itemPhotoUrl: _itemPhotoUrl,
                      ))
                  : null,
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
            ImagePickerField(
              value: _shippingProofUrl,
              label: _busy ? l10n.actionUploading : l10n.actionUploadShippingProof,
              onChanged: (url) => setState(() => _shippingProofUrl = url),
            ),
            const SizedBox(height: 12),
            primary(
              l10n.actionMarkShipped,
              () => _run(() => repo.markShipped(o.id, shippingProofUrl: _shippingProofUrl)),
            ),
          ],
        );
      case 'in_transit':
        if (!widget.isShopper) {
          if (o.shippingProofUrl != null) {
            return note(l10n.noteShippedWaitingConfirm);
          }
          // The picker at ship-time was skipped — still let the traveler
          // attach proof while the order is in transit, not just then.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              note(l10n.noteShippedWaitingConfirm),
              const SizedBox(height: 12),
              ImagePickerField(
                value: _shippingProofUrl,
                label: _busy ? l10n.actionUploading : l10n.actionUploadShippingProof,
                onChanged: (url) => setState(() => _shippingProofUrl = url),
              ),
              const SizedBox(height: 12),
              primary(
                l10n.actionSubmit,
                _shippingProofUrl != null
                    ? () => _run(() => repo.addShippingProof(o.id, _shippingProofUrl!))
                    : null,
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            note(l10n.noteOnWayConfirm),
            const SizedBox(height: 12),
            Text(l10n.labelDeliveryProof, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              l10n.hintDeliveryProofRequired,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            ImagePickerField(
              value: _deliveryProofUrl,
              label: _busy ? l10n.actionUploading : l10n.actionUploadDeliveryPhoto,
              onChanged: (url) => setState(() => _deliveryProofUrl = url),
            ),
            const SizedBox(height: 12),
            primary(
              l10n.actionConfirmRelease(o.totalLabel),
              _deliveryProofUrl != null
                  ? () => _confirmRelease(o.id, o.totalLabel, _deliveryProofUrl!)
                  : null,
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
            () => context.push('/orders/${o.id}/confirm'),
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

/// "You have N days left to upload..." — shown above the item-photo/receipt
/// upload fields once payment is confirmed, counting down to the linked
/// trip's return date. The backend also nudges the traveler about this via
/// a roughly-daily notification (see `src/services/upload-reminder.ts`);
/// this is the same deadline surfaced right where they need to act on it.
class _UploadDeadlineBanner extends StatelessWidget {
  const _UploadDeadlineBanner({required this.daysLeft});
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final urgent = daysLeft <= 1;
    final scheme = Theme.of(context).colorScheme;
    final fg = urgent ? scheme.onErrorContainer : scheme.onPrimaryContainer;

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
          Expanded(
            child: Text(
              l10n.noteUploadDaysLeft(daysLeft),
              style: TextStyle(color: fg, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reserved space for the PromptPay QR code a real payment gateway (e.g.
/// Xendit) will generate — no gateway is wired up yet (manual-money pilot),
/// so this is a placeholder box, not a real code. Swap this out for the
/// actual generated image once that integration lands.
class _PromptPayQrPlaceholder extends StatelessWidget {
  const _PromptPayQrPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      child: Column(
        children: [
          Text(l10n.promptPayQrTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(
              Icons.qr_code_2,
              size: 96,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.promptPayQrComingSoon,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Purchase evidence the traveler uploaded — the shop receipt, and (once
/// this shipped) a photo of the item itself. Visible to both parties and
/// the operator; tap either photo to view full-screen. Older orders may
/// only have a receipt (uploaded before the item-photo field existed).
class _PurchaseProofCard extends StatelessWidget {
  const _PurchaseProofCard({required this.receiptUrl, this.itemPhotoUrl, this.at});
  final String receiptUrl;
  final String? itemPhotoUrl;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final captionStyle = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);
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
          if (itemPhotoUrl != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.labelItemPhoto, style: captionStyle),
                      const SizedBox(height: 4),
                      HeroImage(
                        url: itemPhotoUrl,
                        fallbackAsset: 'assets/images/electronics.jpg',
                        height: 130,
                        borderRadius: 12,
                        enableFullscreen: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.labelReceipt, style: captionStyle),
                      const SizedBox(height: 4),
                      HeroImage(
                        url: receiptUrl,
                        fallbackAsset: 'assets/images/electronics.jpg',
                        height: 130,
                        borderRadius: 12,
                        enableFullscreen: true,
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            HeroImage(
              url: receiptUrl,
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

/// Optional evidence the traveler shipped the item — a photo with the
/// courier or a screenshot of the delivery app's booking page. Unlike the
/// purchase receipt this is never required, so the card only shows up once
/// one has actually been uploaded.
class _ShippingProofCard extends StatelessWidget {
  const _ShippingProofCard({required this.url, this.at});
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
                Icons.local_shipping_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.shippingProofTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if (at != null)
                Text(
                  shortDate(at),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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

/// The shopper's required proof-of-receipt photo — what unlocks the payment
/// release.
class _DeliveryProofCard extends StatelessWidget {
  const _DeliveryProofCard({required this.url, this.at});
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
                Icons.inventory_2_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.deliveryProofTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if (at != null)
                Text(
                  shortDate(at),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
