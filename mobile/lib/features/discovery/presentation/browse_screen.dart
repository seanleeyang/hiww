import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/async_value_view.dart';
import '../../../ui/category_chips.dart';
import '../../../ui/country_chips.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/skeleton.dart';
import '../../wants/presentation/post_want_sheet.dart';
import '../data/discovery_repository.dart';
import '../domain/feed_item.dart';
import 'feed_cards.dart';

final browseCategoryProvider = StateProvider<String?>((_) => null);
final browseCountryProvider = StateProvider<String?>((_) => null);

enum TripSort { newest, departingSoon }

enum WantSort { newest, neededSoon }

const _tripSortLabels = {
  TripSort.newest: 'Newest posted',
  TripSort.departingSoon: 'Departing soonest',
};

const _wantSortLabels = {
  WantSort.newest: 'Newest posted',
  WantSort.neededSoon: 'Needed soonest',
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
      tooltip: 'Sort',
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

/// Trips and wants used to share one combined feed filtered by product
/// category — but a trip has no category, only a route, so every trip
/// showed up under every category chip. Split into two tabs so each side's
/// filter actually matches its content: trips by country (what a shopper
/// browsing for a traveler cares about), wants by category (what a
/// traveler browsing for an offer opportunity cares about). Either role can
/// still check the other tab — posting isn't role-gated server-side — the
/// tab just decides which filter and FAB are in front by default.
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

  @override
  Widget build(BuildContext context) {
    final onTripsTab = _tabController.index == 0;

    return Scaffold(
      floatingActionButton: onTripsTab
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/trips/new'),
              icon: const Icon(Icons.add),
              label: const Text('Post a trip'),
            )
          : FloatingActionButton.extended(
              onPressed: () => showPostWantSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Post a want'),
            ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Trips'),
              Tab(text: 'Wants'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: const [_TripsBrowseTab(), _WantsBrowseTab()],
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

    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
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
              labels: _tripSortLabels,
              onChanged: (v) => ref.read(tripSortProvider.notifier).state = v,
            ),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.pullToRefresh(feedProvider(query).future),
            child: AsyncValueView(
              value: feed,
              onRetry: () => ref.invalidate(feedProvider(query)),
              loading: (_) => const FeedSkeleton(),
              data: (rawItems) {
                final items = _sortedTrips(rawItems, sort);
                if (items.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 80),
                      EmptyState(
                        icon: Icons.flight_outlined,
                        title: 'No trips here yet',
                        message:
                            'No travelers heading this way yet. Check back soon, or '
                            'post your own trip if you\'re the one traveling.',
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final item = items[i];
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
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _WantsBrowseTab extends ConsumerWidget {
  const _WantsBrowseTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(browseCategoryProvider);
    final sort = ref.watch(wantSortProvider);
    final query = (type: 'wants', category: category, country: null);
    final feed = ref.watch(feedProvider(query));

    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
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
              labels: _wantSortLabels,
              onChanged: (v) => ref.read(wantSortProvider.notifier).state = v,
            ),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.pullToRefresh(feedProvider(query).future),
            child: AsyncValueView(
              value: feed,
              onRetry: () => ref.invalidate(feedProvider(query)),
              loading: (_) => const FeedSkeleton(),
              data: (rawItems) {
                final items = _sortedWants(rawItems, sort);
                if (items.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 80),
                      EmptyState(
                        icon: Icons.explore_off_outlined,
                        title: 'Nothing here yet',
                        message:
                            'No wants match this filter. Check back soon, or post a '
                            'want of your own.',
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    if (item.want == null) return const SizedBox.shrink();
                    return WantFeedCard(
                      want: item.want!,
                      shopper: item.owner,
                      matchCount: item.matchCount,
                      onTap: () => context.push('/wants/${item.want!.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
