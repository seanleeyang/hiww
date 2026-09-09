import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/countries.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/hero_image.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/skeleton.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/status_pill.dart';
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
        case 'purchased':
          requested.add(_OrderEntry(o));
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

    final wants = wantsAsync.valueOrNull;
    final orders = ordersAsync.valueOrNull;
    final negotiations = negotiationsAsync.valueOrNull;
    final orderMap = orderMapAsync.valueOrNull;

    void refreshAll() {
      ref.invalidate(myWantsProvider);
      ref.invalidate(myOrdersProvider);
      ref.invalidate(negotiationsProvider);
      ref.invalidate(orderIdByRequestProvider);
    }

    Widget body;
    _Buckets? buckets;
    if (wants == null || orders == null || negotiations == null || orderMap == null) {
      final err = wantsAsync.error ?? ordersAsync.error;
      body = err != null
          ? EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Something went wrong',
              message: err is ApiException ? err.message : 'Please try again.',
              action: FilledButton.tonal(onPressed: refreshAll, child: const Text('Retry')),
            )
          // FeedSkeleton is a plain Column (not a ListView) — it needs a
          // scrollable ancestor of its own here, unlike its other use inside
          // a CustomScrollView's SliverToBoxAdapter on the Home screen.
          : const SingleChildScrollView(child: FeedSkeleton());
    } else {
      buckets = _bucket(wants, orders, negotiations, orderMap);
      body = TabBarView(
        controller: _tabController,
        children: [
          _EntryList(
            entries: buckets.requested,
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
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateOrderSheet(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.actionPostAWant),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.ordersTabRequested(buckets?.requested.length ?? 0)),
              Tab(text: l10n.ordersTabInTransit(buckets?.inTransit.length ?? 0)),
              Tab(text: l10n.ordersTabReceived(buckets?.received.length ?? 0)),
              Tab(text: l10n.ordersTabInactive(buckets?.inactive.length ?? 0)),
            ],
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: () async => refreshAll(), child: body),
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
    final ok = await showDialog<bool>(
      context: context,
      // Shadow `context` with the dialog's own — this screen lives inside
      // the bottom-tab shell, not the root navigator.
      builder: (context) => AlertDialog(
        title: Text(l10n.dialogRemoveWantTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.dialogRemoveFromListBody),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => context.pop(true),
              child: Text(l10n.actionRemove),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => context.pop(false), child: Text(l10n.actionCancel)),
          ],
        ),
      ),
    );
    if (ok != true) return;
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
    // A pending offer is negotiation in progress — surface that on the
    // pill instead of the want's own (still just "open") status. Tapping
    // through to the want's detail page is where the actual offer/counter/
    // decline controls live; the card itself stays a plain summary.
    final displayStatus = widget.pendingOffer != null ? 'negotiating' : w.status;
    return SoftCard(
      onTap: () => context.push('/wants/${w.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(w.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              StatusPill(displayStatus),
              if (_archivableWantStatuses.contains(w.status)) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: l10n.tooltipRemoveFromList,
                  onPressed: () => _archive(context),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            IconLine(Icons.sell_outlined, l10n.wantBudgetLine(w.budgetLabel)),
            IconLine(Icons.public, l10n.wantBuyInLine(w.sourceCity ?? countryName(w.sourceCountry))),
            if (w.needByLabel != null) IconLine(Icons.event_outlined, w.needByLabel!),
          ]),
        ],
      ),
    );
  }
}

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
    return SoftCard(
      onTap: () => context.push('/wants/${o.requestId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(o.requestItem ?? l10n.fallbackOfferTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              const StatusPill('negotiating'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            IconLine(Icons.sell_outlined, o.priceLabel),
            if (o.counterpartyName != null)
              IconLine(Icons.person_outline, o.counterpartyName!),
          ]),
        ],
      ),
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
                  Text(o.totalLabel, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ]),
                if (next != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.arrow_forward, size: 13, color: scheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(next,
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.primary)),
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
