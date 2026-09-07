import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/countries.dart';
import '../../../ui/async_value_view.dart';
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
import '../../shared/presentation/reviews_preview.dart';
import '../data/wants_repository.dart';
import '../domain/offer.dart';
import 'post_want_sheet.dart';

class WantDetailScreen extends ConsumerWidget {
  const WantDetailScreen({super.key, required this.wantId});
  final String wantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(wantDetailProvider(wantId));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Want')),
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
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconLine(
                          Icons.sell_outlined,
                          'Budget ${want.budgetLabel}',
                        ),
                        if (want.quantity > 1) ...[
                          const SizedBox(height: 6),
                          IconLine(Icons.numbers, 'Quantity ${want.quantity}'),
                        ],
                        const SizedBox(height: 6),
                        IconLine(
                          Icons.public,
                          'Buy in ${want.sourceCity ?? countryName(want.sourceCountry)}',
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
                                  showPostWantSheet(context, existing: want),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _cancelWant(context, ref, want.id),
                              icon: Icon(Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error),
                              label: Text('Cancel',
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
                      label: const Text('Make an offer'),
                    )
                  else if (want.status != 'open')
                    Text(
                      'This want is no longer taking offers.',
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
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel this want?'),
      content: const Text(
        'Travelers will no longer see it or be able to offer on it. This can\'t be undone.',
      ),
      actions: [
        TextButton(onPressed: () => context.pop(false), child: const Text('Keep want')),
        FilledButton(
          onPressed: () => context.pop(true),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Cancel want'),
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
    final offers = ref.watch(wantOffersProvider(wantId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Offers'),
        AsyncValueView(
          value: offers,
          onRetry: () => ref.invalidate(wantOffersProvider(wantId)),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'No offers yet — travelers on this route will see it.',
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
  bool _busy = false;

  Future<void> _accept() async {
    final o = widget.offer;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept this offer?'),
        content: Text(
          'You will pay ${o.priceLabel} for the goods. An order is created and '
          "you'll be asked to pay.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final orderId = await ref.read(wantsRepositoryProvider).acceptOffer(o.id);
      ref.invalidate(myWantsProvider);
      ref.invalidate(myOrdersProvider);
      ref.invalidate(wantDetailProvider(widget.wantId));
      ref.invalidate(wantOffersProvider(widget.wantId));
      if (!mounted) return;
      context.go('/orders/$orderId');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        action: e.code == 'PROFILE_INCOMPLETE'
            ? SnackBarAction(label: 'Update profile', onPressed: () => context.push('/account'))
            : null,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: o.travelerName ?? 'Traveler', radius: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  o.travelerName ?? 'Traveler',
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
          if (widget.canAccept) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _accept,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Accept offer'),
            ),
          ],
        ],
      ),
    );
  }
}
