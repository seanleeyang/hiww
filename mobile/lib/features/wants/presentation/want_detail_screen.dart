import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/countries.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/breakdown_row.dart';
import '../../../ui/hero_image.dart';
import '../../../ui/initials_avatar.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/responsive_body.dart';
import '../../../ui/section_header.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/status_pill.dart';
import '../../../ui/stock_images.dart';
import '../../auth/application/auth_controller.dart';
import '../../orders/data/orders_repository.dart';
import '../../shared/data/pricing_repository.dart';
import '../../shared/domain/pricing_preview.dart';
import '../../shared/presentation/reviews_preview.dart';
import '../data/offers_repository.dart';
import '../data/wants_repository.dart';
import '../domain/offer.dart';
import 'offer_negotiation_actions.dart';
import 'post_want_sheet.dart';

class WantDetailScreen extends ConsumerWidget {
  const WantDetailScreen({super.key, required this.wantId});
  final String wantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(wantDetailProvider(wantId));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.wantDetailTitle)),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: detail,
          onRetry: () => ref.invalidate(wantDetailProvider(wantId)),
          data: (d) {
            final want = d.want;
            final mine = me?.id == want.shopperId;
            final iAmTraveler = me?.userType.isTraveler ?? false;

            return RefreshIndicator(
              onRefresh: () => ref.pullToRefreshAll([
                wantDetailProvider(wantId).future,
                if (mine) wantOffersProvider(wantId).future,
              ]),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  HeroImage(
                    url: want.imageUrl,
                    fallbackAsset: stockForCategory(want.category),
                    height: 200,
                    heroTag: 'want-${want.id}',
                    enableFullscreen: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          want.displayTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      StatusPill(want.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(want.itemDescription),
                  if (want.isDirectRequest) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          l10n.directRequestBadge,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconLine(
                          Icons.sell_outlined,
                          l10n.wantBudgetLine(want.budgetLabel),
                        ),
                        if (want.quantity > 1) ...[
                          const SizedBox(height: 6),
                          IconLine(Icons.numbers, l10n.wantQuantityLine(want.quantity)),
                        ],
                        const SizedBox(height: 6),
                        IconLine(
                          Icons.public,
                          l10n.wantBuyInLine(want.sourceCity ?? countryName(want.sourceCountry)),
                        ),
                        if (want.needByLabel != null) ...[
                          const SizedBox(height: 6),
                          IconLine(Icons.event_outlined, want.needByLabel!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (d.shopper != null) ...[
                    AvatarRating(user: d.shopper!, radius: 20),
                    const SizedBox(height: 16),
                    ReviewsPreview(userId: want.shopperId, max: 2),
                  ],
                  const SizedBox(height: 8),
                  if (mine) ...[
                    _OffersSection(
                      wantId: wantId,
                      requestOpen: want.status == 'open',
                    ),
                    if (want.status == 'open') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  showEditWantSheet(context, existing: want),
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(l10n.actionEdit),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _cancelWant(context, ref, want.id),
                              icon: Icon(Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error),
                              label: Text(l10n.actionCancel,
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.error)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else if (iAmTraveler && want.status == 'open')
                    FilledButton.icon(
                      onPressed: () => context.push('/wants/$wantId/offer'),
                      icon: const Icon(Icons.local_offer_outlined),
                      label: Text(l10n.actionMakeAnOffer),
                    )
                  else if (want.status != 'open')
                    Text(
                      l10n.wantClosedNote,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _cancelWant(BuildContext context, WidgetRef ref, String wantId) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.dialogCancelWantTitle),
      content: Text(l10n.dialogCancelWantBody),
      actions: [
        TextButton(onPressed: () => context.pop(false), child: Text(l10n.actionKeepWant)),
        FilledButton(
          onPressed: () => context.pop(true),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: Text(l10n.actionCancelWant),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await ref.read(wantsRepositoryProvider).cancel(wantId);
    ref.invalidate(myWantsProvider);
    ref.invalidate(wantDetailProvider(wantId));
    if (context.mounted) context.pop();
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _OffersSection extends ConsumerWidget {
  const _OffersSection({required this.wantId, required this.requestOpen});
  final String wantId;
  final bool requestOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final offers = ref.watch(wantOffersProvider(wantId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(l10n.tabOffers),
        AsyncValueView(
          value: offers,
          onRetry: () => ref.invalidate(wantOffersProvider(wantId)),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                l10n.noOffersYetMessage,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              children: [
                for (final o in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OfferCard(
                      wantId: wantId,
                      offer: o,
                      canAccept: requestOpen && o.status == 'pending',
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({
    required this.wantId,
    required this.offer,
    required this.canAccept,
  });
  final String wantId;
  final Offer offer;
  final bool canAccept;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  Future<void> _refreshAfterAction() async {
    ref.invalidate(wantDetailProvider(widget.wantId));
    ref.invalidate(wantOffersProvider(widget.wantId));
    ref.invalidate(negotiationsProvider);
  }

  Future<void> _accept() async {
    final l10n = AppLocalizations.of(context)!;
    final o = widget.offer;

    PricingPreview? pricing;
    try {
      pricing = await ref.read(pricingRepositoryProvider).preview(o.quotedPrice);
    } catch (_) {
      // Fall back to the plain price below if the preview call fails —
      // don't block accepting an offer over a display-only breakdown.
    }
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dialogAcceptOfferTitle),
        content: pricing == null
            ? Text(l10n.dialogAcceptOfferBody(o.priceLabel))
            : _PriceBreakdown(pricing: pricing),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => context.pop(true),
                child: Text(l10n.actionAccept),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(false),
                child: Text(l10n.actionCancel),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final orderId = await ref.read(offersRepositoryProvider).accept(o.id);
      ref.invalidate(myWantsProvider);
      ref.invalidate(myOrdersProvider);
      await _refreshAfterAction();
      if (!mounted) return;
      context.go('/orders/$orderId');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        action: e.code == 'PROFILE_INCOMPLETE'
            ? SnackBarAction(label: 'Update profile', onPressed: () => context.push('/account'))
            : null,
      ));
    }
  }

  Future<void> _counter(String price) async {
    await ref.read(offersRepositoryProvider).counter(widget.offer.id, price);
    await _refreshAfterAction();
  }

  Future<void> _reject() async {
    await ref.read(offersRepositoryProvider).reject(widget.offer.id);
    await _refreshAfterAction();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final o = widget.offer;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: o.travelerName ?? l10n.fallbackTraveler, radius: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  o.travelerName ?? l10n.fallbackTraveler,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              StatusPill(o.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                o.priceLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (o.deliveryLabel != null) ...[
                const SizedBox(width: 12),
                Text(
                  o.deliveryLabel!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          if (o.isNegotiating) ...[
            const SizedBox(height: 4),
            Text(
              l10n.offerCounteredTimes(o.round),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
          if (o.status == 'pending') ...[
            const SizedBox(height: 12),
            OfferNegotiationActions(
              offer: o,
              enabled: widget.canAccept,
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

/// Itemized shopper-facing breakdown shown before accepting an offer —
/// Product price / Traveller reward / Service & protection fee / = Total —
/// rather than a single vague "X% fee".
class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({required this.pricing});
  final PricingPreview pricing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BreakdownRow(l10n.priceBreakdownProductPrice, pricing.itemPriceLabel),
        BreakdownRow(l10n.priceBreakdownTravellerReward, pricing.travellerRewardLabel),
        BreakdownRow(l10n.priceBreakdownServiceFee, pricing.serviceFeeLabel),
        const Divider(height: 16),
        BreakdownRow(l10n.priceBreakdownTotal, pricing.shopperTotalLabel, bold: true),
      ],
    );
  }
}
