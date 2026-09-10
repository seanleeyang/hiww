import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/badged_fab.dart';
import '../../../ui/confirm_dialog.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/marketplace_order_card.dart';
import '../../../ui/skeleton.dart';
import '../../../ui/stock_images.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../../wants/data/offers_repository.dart';
import '../../wants/data/wants_repository.dart';
import '../../wants/domain/offer.dart';
import '../../wants/domain/want.dart';
import '../../wants/presentation/create_order_sheet.dart';
import '../data/orders_repository.dart';
import '../domain/order.dart';

/// Either side of a "Requested"/"Inactive" bucket entry — a want that hasn't
/// become an order yet, or an order itself. Both render in the same list,
/// sorted together by recency.
sealed class _Entry {
  DateTime get sortKey;
}

class _WantEntry extends _Entry {
  _WantEntry(this.want, this.pendingOffer);
  final Want want;
  final Offer? pendingOffer;
  @override
  DateTime get sortKey => want.createdAt ?? DateTime(0);
}

class _OrderEntry extends _Entry {
  _OrderEntry(this.order);
  final Order order;
  @override
  DateTime get sortKey => order.createdAt ?? DateTime(0);
}

/// An offer the caller made as a traveler that's still awaiting a decision.
/// The shopper's side of the same negotiation surfaces via a `pendingOffer`
/// on their own `_WantEntry` below — but the traveler has no want of their
/// own to attach it to, so it needs its own card, or it's invisible to them
/// anywhere except a notification's deep link.
class _NegotiationEntry extends _Entry {
  _NegotiationEntry(this.offer);
  final Offer offer;
  @override
  DateTime get sortKey => offer.createdAt ?? DateTime(0);
}

typedef _Buckets = ({
  List<_Entry> requested,
  List<Order> inTransit,
  List<Order> received,
  List<_Entry> inactive,
});

/// One place to see every order the signed-in user is part of — as a shopper
/// buying, or a traveler delivering — plus their own wants that haven't
/// turned into an order yet, grouped by stage (Requested / In Transit /
/// Received / Inactive), matching how far along the item actually is.
class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static _Buckets _bucket(
    List<Want> wants,
    List<Order> orders,
    List<Offer> negotiations,
    Map<String, String> orderIdByRequest,
  ) {
    final pendingByRequest = {
      for (final o in negotiations)
        if (o.myRole == 'shopper' && o.status == 'pending' && o.requestId != null)
          o.requestId!: o,
    };

    final requested = <_Entry>[];
    final inactive = <_Entry>[];
    final inTransit = <Order>[];
    final received = <Order>[];

    for (final w in wants) {
      if (w.status == 'cancelled') {
        inactive.add(_WantEntry(w, null));
      } else if (w.status == 'open' && orderIdByRequest[w.id] == null) {
        requested.add(_WantEntry(w, pendingByRequest[w.id]));
      }
      // 'accepted' wants are represented by their linked order below instead.
    }

    for (final o in negotiations) {
      if (o.myRole == 'traveler' && o.status == 'pending' && o.requestId != null) {
        requested.add(_NegotiationEntry(o));
      }
    }

    for (final o in orders) {
      switch (o.status) {
        case 'pending_payment':
        case 'confirmed':
          requested.add(_OrderEntry(o));
        // Once the traveler has bought the item (photo + receipt uploaded),
        // the shopper's job is done and the item is on its way to being
        // shipped — that reads as "in progress" to both sides, not still
        // "requested", even though shipping itself hasn't started yet.
        case 'purchased':
        case 'in_transit':
          inTransit.add(o);
        case 'delivered':
          received.add(o);
        case 'cancelled':
          inactive.add(_OrderEntry(o));
      }
    }

    int byRecency(_Entry a, _Entry b) => b.sortKey.compareTo(a.sortKey);
    int orderByRecency(Order a, Order b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
    requested.sort(byRecency);
    inactive.sort(byRecency);
    inTransit.sort(orderByRecency);
    received.sort(orderByRecency);

    return (
      requested: requested,
      inTransit: inTransit,
      received: received,
      inactive: inactive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final wantsAsync = ref.watch(myWantsProvider);
    final ordersAsync = ref.watch(myOrdersProvider);
    final negotiationsAsync = ref.watch(negotiationsProvider);
    final orderMapAsync = ref.watch(orderIdByRequestProvider);
    final me = ref.watch(currentUserProvider);
    final combined = combine4(wantsAsync, ordersAsync, negotiationsAsync, orderMapAsync);
    final combinedValue = combined.valueOrNull;
    final buckets = combinedValue == null
        ? null
        : _bucket(combinedValue.$1, combinedValue.$2, combinedValue.$3, combinedValue.$4);

    void refreshAll() {
      ref.invalidate(myWantsProvider);
      ref.invalidate(myOrdersProvider);
      ref.invalidate(negotiationsProvider);
      ref.invalidate(orderIdByRequestProvider);
    }

    return Scaffold(
      floatingActionButton: BadgedFab(
        icon: Icons.shopping_bag_outlined,
        onPressed: () => showCreateOrderSheet(context),
        tooltip: l10n.actionPostAWant,
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: buckets == null ? l10n.ordersTabRequestedPlain : l10n.ordersTabRequested(buckets.requested.length)),
              Tab(text: buckets == null ? l10n.ordersTabInTransitPlain : l10n.ordersTabInTransit(buckets.inTransit.length)),
              Tab(text: buckets == null ? l10n.ordersTabReceivedPlain : l10n.ordersTabReceived(buckets.received.length)),
              Tab(text: buckets == null ? l10n.ordersTabInactivePlain : l10n.ordersTabInactive(buckets.inactive.length)),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => refreshAll(),
              child: AsyncValueView(
                value: combined,
                onRetry: refreshAll,
                // FeedSkeleton is a plain Column (not a ListView) — it needs
                // a scrollable ancestor of its own here, unlike its other use
                // inside a CustomScrollView's SliverToBoxAdapter on Home.
                loading: (context) => const SingleChildScrollView(child: FeedSkeleton()),
                data: (_) => TabBarView(
                  controller: _tabController,
                  children: [
                    _EntryList(
                      entries: buckets!.requested,
                      me: me,
                      emptyIcon: Icons.receipt_long_outlined,
                      emptyTitle: l10n.emptyMyWantsTitle,
                      emptyMessage: l10n.emptyMyWantsMessage,
                      emptyAction: FilledButton(
                        onPressed: () => showCreateOrderSheet(context),
                        child: Text(l10n.actionPostAWant),
                      ),
                    ),
                    _OrderList(orders: buckets.inTransit, me: me),
                    _OrderList(orders: buckets.received, me: me),
                    _EntryList(
                      entries: buckets.inactive,
                      me: me,
                      emptyIcon: Icons.inventory_2_outlined,
                      emptyTitle: l10n.emptyOrdersBucketTitle,
                      emptyMessage: l10n.emptyOrdersBucketMessage,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.entries,
    required this.me,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    this.emptyAction,
  });

  final List<_Entry> entries;
  final AuthUser? me;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        EmptyState(icon: emptyIcon, title: emptyTitle, message: emptyMessage, action: emptyAction),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final e = entries[i];
        return switch (e) {
          _WantEntry() => _WantCard(want: e.want, pendingOffer: e.pendingOffer),
          _OrderEntry() => _OrderCard(order: e.order, isShopper: me?.id == e.order.shopperId),
          _NegotiationEntry() => _NegotiationCard(offer: e.offer),
        };
      },
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.me});
  final List<Order> orders;
  final AuthUser? me;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (orders.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        EmptyState(
          icon: Icons.local_shipping_outlined,
          title: l10n.emptyOrdersBucketTitle,
          message: l10n.emptyOrdersBucketMessage,
        ),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final o = orders[i];
        return _OrderCard(order: o, isShopper: me?.id == o.shopperId);
      },
    );
  }
}

const _archivableWantStatuses = {'cancelled', 'completed'};

class _WantCard extends ConsumerStatefulWidget {
  const _WantCard({required this.want, this.pendingOffer});
  final Want want;
  final Offer? pendingOffer;

  @override
  ConsumerState<_WantCard> createState() => _WantCardState();
}

class _WantCardState extends ConsumerState<_WantCard> {
  Future<void> _archive(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showRemoveFromListDialog(
      context,
      title: l10n.dialogRemoveWantTitle,
      body: l10n.dialogRemoveFromListBody,
      confirmLabel: l10n.actionRemove,
      cancelLabel: l10n.actionCancel,
    );
    if (!ok) return;
    try {
      await ref.read(wantsRepositoryProvider).archive(widget.want.id);
      ref.invalidate(myWantsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final w = widget.want;
    final offer = widget.pendingOffer;
    // A pending offer is negotiation in progress — surface that on the
    // pill instead of the want's own (still just "open") status, and show
    // its current price instead of the asking budget. Tapping through to
    // the want's detail page is where the actual offer/counter/decline
    // controls live; the card itself stays a plain summary.
    return MarketplaceOrderCard(
      imageUrl: w.imageUrl,
      fallbackAsset: stockForCategory(w.category),
      title: w.displayTitle,
      subtitle: offer != null && offer.counterpartyName != null
          ? l10n.offerFromLabel(offer.counterpartyName!)
          : null,
      status: offer != null ? 'negotiating' : w.status,
      priceLabel: offer?.priceLabel ?? w.budgetLabel,
      ctaIcon: offer != null ? Icons.arrow_forward : null,
      ctaText: offer != null ? _negotiationCta(l10n, offer) : (w.status == 'open' ? l10n.nextStepWaitingForOffers : null),
      onTap: () => context.push('/wants/${w.id}'),
      trailing: _archivableWantStatuses.contains(w.status)
          ? IconButton(
              tooltip: l10n.tooltipRemoveFromList,
              onPressed: () => _archive(context),
              icon: const Icon(Icons.close, size: 18),
            )
          : null,
    );
  }
}

/// Plain-language "what happens next" for a pending offer, from this
/// viewer's point of view — shared by the shopper's want card (with a
/// `pendingOffer`) and the traveler's own outgoing-offer card.
String _negotiationCta(AppLocalizations l10n, Offer offer) =>
    offer.myTurn ? l10n.nextStepOfferNeedsResponse : l10n.nextStepWaitingOnOtherSide;

/// A traveler's own outgoing offer, still being negotiated. A plain summary
/// card like any other — the actual offer/counter/decline controls only
/// show once tapped through to the want's detail page.
class _NegotiationCard extends StatelessWidget {
  const _NegotiationCard({required this.offer});
  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final o = offer;
    return MarketplaceOrderCard(
      imageUrl: o.requestImageUrl,
      fallbackAsset: stockForCategory(o.requestCategory),
      title: o.requestItem ?? l10n.fallbackOfferTitle,
      subtitle: o.counterpartyName != null ? l10n.offerToLabel(o.counterpartyName!) : null,
      status: 'negotiating',
      priceLabel: o.priceLabel,
      ctaIcon: Icons.arrow_forward,
      ctaText: _negotiationCta(l10n, o),
      onTap: () => context.push('/wants/${o.requestId}'),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.isShopper});

  final Order order;
  final bool isShopper;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final o = order;
    final who = o.counterparty?.fullName ?? (isShopper ? l10n.fallbackATraveler : l10n.fallbackAShopper);
    final relation = isShopper ? l10n.orderRelationBuying(who) : l10n.orderRelationDelivering(who);
    final next = _nextStep(l10n, o.status, isShopper);

    return MarketplaceOrderCard(
      imageUrl: o.requestImageUrl,
      fallbackAsset: stockForCategory(o.requestCategory),
      title: o.itemDescription,
      subtitle: relation,
      status: o.status,
      priceLabel: o.totalLabel,
      ctaIcon: next != null ? Icons.arrow_forward : null,
      ctaText: next,
      onTap: () => context.push('/orders/${o.id}'),
    );
  }

  /// Plain-language "what happens next", from this user's point of view.
  static String? _nextStep(AppLocalizations l10n, String status, bool isShopper) => switch (status) {
        'pending_payment' =>
          isShopper ? l10n.nextStepPayToStart : l10n.nextStepWaitingForPayment,
        'confirmed' => isShopper ? l10n.nextStepTravelerBuying : l10n.nextStepBuyThenUpload,
        'purchased' => isShopper ? l10n.nextStepBoughtWaitShip : l10n.nextStepPostThenShip,
        'in_transit' => isShopper ? l10n.nextStepOnWayConfirm : l10n.nextStepShippedWaiting,
        'delivered' => null,
        'cancelled' => null,
        _ => null,
      };
}
