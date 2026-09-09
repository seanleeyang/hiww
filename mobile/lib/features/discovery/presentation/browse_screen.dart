import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/guest_guard.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart' show PullToRefresh;
import '../../../ui/category_chips.dart';
import '../../../ui/country_chips.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../../trips/presentation/add_trip_sheet.dart';
import '../../trips/presentation/travel_hero_form.dart';
import '../../wants/presentation/create_order_sheet.dart';
import '../data/discovery_repository.dart';
import '../domain/feed_item.dart';
import 'browse_hero.dart';
import 'feed_cards.dart';

final browseCategoryProvider = StateProvider<String?>((_) => null);
final browseCountryProvider = StateProvider<String?>((_) => null);

enum TripSort { newest, departingSoon }

enum WantSort { newest, neededSoon }

Map<TripSort, String> _tripSortLabels(AppLocalizations l10n) => {
  TripSort.newest: l10n.sortNewestPosted,
  TripSort.departingSoon: l10n.sortDepartingSoonest,
};

Map<WantSort, String> _wantSortLabels(AppLocalizations l10n) => {
  WantSort.newest: l10n.sortNewestPosted,
  WantSort.neededSoon: l10n.sortNeededSoonest,
};

final tripSortProvider = StateProvider<TripSort>((_) => TripSort.newest);
final wantSortProvider = StateProvider<WantSort>((_) => WantSort.newest);

List<FeedItem> _sortedTrips(List<FeedItem> items, TripSort sort) {
  if (sort == TripSort.newest) return items;
  final sorted = [...items];
  sorted.sort((a, b) {
    final ad = a.trip?.departureDate;
    final bd = b.trip?.departureDate;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  });
  return sorted;
}

List<FeedItem> _sortedWants(List<FeedItem> items, WantSort sort) {
  if (sort == WantSort.newest) return items;
  final sorted = [...items];
  sorted.sort((a, b) {
    final an = a.want?.needBy;
    final bn = b.want?.needBy;
    if (an == null && bn == null) return 0;
    if (an == null) return 1;
    if (bn == null) return -1;
    return an.compareTo(bn);
  });
  return sorted;
}

class _SortButton<T> extends StatelessWidget {
  const _SortButton({required this.value, required this.labels, required this.onChanged});
  final T value;
  final Map<T, String> labels;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: AppLocalizations.of(context)!.tooltipSort,
      icon: const Icon(Icons.sort),
      itemBuilder: (context) => [
        for (final entry in labels.entries)
          PopupMenuItem(
            value: entry.key,
            child: Row(
              children: [
                if (entry.key == value)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(entry.value),
              ],
            ),
          ),
      ],
    );
  }
}

/// Two tabs, each pairing its content with the matching action: **Order**
/// browses wants (what shoppers are asking for) with a category filter, and
/// its action posts a want (start your own order); **Travel** browses trips
/// (travelers heading somewhere) with a country filter, and its action
/// posts a trip. Either role can still check the other tab — posting isn't
/// role-gated server-side — the tab just decides which filter and action
/// are in front by default.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this)..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _postWant() {
    if (requireSignedIn(context, ref)) showCreateOrderSheet(context);
  }

  void _postTrip() => showAddTripSheet(context);

  @override
  Widget build(BuildContext context) {
    final onTravelTab = _tabController.index == 0;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      floatingActionButton: onTravelTab
          ? FloatingActionButton.extended(
              onPressed: _postTrip,
              icon: const Icon(Icons.add),
              label: Text(l10n.actionPostATrip),
            )
          : FloatingActionButton(
              onPressed: _postWant,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 24),
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 9,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.browseTabTravel),
              Tab(text: l10n.browseTabOrder),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                const _TripsBrowseTab(),
                _WantsBrowseTab(onPostWant: _postWant),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripsBrowseTab extends ConsumerWidget {
  const _TripsBrowseTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(browseCountryProvider);
    final sort = ref.watch(tripSortProvider);
    final query = (type: 'trips', category: null, country: country);
    final feed = ref.watch(feedProvider(query));
    final l10n = AppLocalizations.of(context)!;
    final name = ref.watch(currentUserProvider)?.firstName;
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => ref.pullToRefresh(feedProvider(query).future),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: TravelHeroForm(
              greeting: name != null
                  ? l10n.heroTravelGreetingNamed(name)
                  : l10n.heroTravelGreetingGuest,
              background: scheme.primary,
              foreground: scheme.onPrimary,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: CountryChips(
                        selected: country,
                        onSelected: (c) =>
                            ref.read(browseCountryProvider.notifier).state = c,
                      ),
                    ),
                  ),
                  _SortButton<TripSort>(
                    value: sort,
                    labels: _tripSortLabels(l10n),
                    onChanged: (v) =>
                        ref.read(tripSortProvider.notifier).state = v,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          ..._feedSlivers(
            feed: feed,
            onRetry: () => ref.invalidate(feedProvider(query)),
            emptyIcon: Icons.flight_outlined,
            emptyTitle: l10n.emptyNoTripsTitle,
            emptyMessage: l10n.emptyNoTripsMessage,
            sort: (rawItems) => _sortedTrips(rawItems, sort),
            itemBuilder: (context, item) {
              if (item.trip == null) return const SizedBox.shrink();
              return TripFeedCard(
                trip: item.trip!,
                traveler: item.owner,
                earnMin: item.earnMin,
                earnMax: item.earnMax,
                matchCount: item.matchCount,
                onTap: () => context.push('/trips/${item.trip!.id}'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WantsBrowseTab extends ConsumerWidget {
  const _WantsBrowseTab({required this.onPostWant});

  final VoidCallback onPostWant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(browseCategoryProvider);
    final sort = ref.watch(wantSortProvider);
    final query = (type: 'wants', category: category, country: null);
    final feed = ref.watch(feedProvider(query));
    final l10n = AppLocalizations.of(context)!;
    final name = ref.watch(currentUserProvider)?.firstName;
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => ref.pullToRefresh(feedProvider(query).future),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: BrowseHero(
              greeting: name != null
                  ? l10n.heroOrderGreetingNamed(name)
                  : l10n.heroOrderGreetingGuest,
              tagline: l10n.heroOrderTagline,
              ctaLabel: l10n.heroOrderCta,
              onCta: onPostWant,
              background: scheme.primary,
              foreground: scheme.onPrimary,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: CategoryChips(
                        selected: category,
                        onSelected: (c) =>
                            ref.read(browseCategoryProvider.notifier).state = c,
                      ),
                    ),
                  ),
                  _SortButton<WantSort>(
                    value: sort,
                    labels: _wantSortLabels(l10n),
                    onChanged: (v) =>
                        ref.read(wantSortProvider.notifier).state = v,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          ..._feedSlivers(
            feed: feed,
            onRetry: () => ref.invalidate(feedProvider(query)),
            emptyIcon: Icons.explore_off_outlined,
            emptyTitle: l10n.emptyNoWantsTitle,
            emptyMessage: l10n.emptyNoWantsMessage,
            sort: (rawItems) => _sortedWants(rawItems, sort),
            itemBuilder: (context, item) {
              if (item.want == null) return const SizedBox.shrink();
              return WantFeedCard(
                want: item.want!,
                shopper: item.owner,
                matchCount: item.matchCount,
                onTap: () => context.push('/wants/${item.want!.id}'),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The shared loading/empty/error/list handling behind both browse tabs,
/// as slivers so the [BrowseHero] and filter row above can scroll away with
/// the feed instead of staying pinned — [AsyncValueView] can't be reused
/// directly here since its `error` branch returns a plain (non-sliver)
/// widget, and it's shared by screens that aren't inside a CustomScrollView.
List<Widget> _feedSlivers({
  required AsyncValue<List<FeedItem>> feed,
  required VoidCallback onRetry,
  required IconData emptyIcon,
  required String emptyTitle,
  required String emptyMessage,
  required List<FeedItem> Function(List<FeedItem> rawItems) sort,
  required Widget Function(BuildContext context, FeedItem item) itemBuilder,
}) {
  return [
    feed.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (rawItems) {
        final items = sort(rawItems);
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: EmptyState(
                icon: emptyIcon,
                title: emptyTitle,
                message: emptyMessage,
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) => itemBuilder(context, items[i]),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: FeedSkeleton()),
      error: (err, _) => SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Something went wrong',
          message: err is ApiException ? err.message : 'Please try again.',
          action: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ),
    ),
  ];
}
