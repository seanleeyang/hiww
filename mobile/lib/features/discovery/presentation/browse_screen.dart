import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/async_value_view.dart';
import '../../../ui/category_chips.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../../wants/presentation/post_want_sheet.dart';
import '../data/discovery_repository.dart';
import 'feed_cards.dart';

final browseCategoryProvider = StateProvider<String?>((_) => null);

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(browseCategoryProvider);
    final query = (type: 'all', category: category);
    final feed = ref.watch(feedProvider(query));
    final user = ref.watch(currentUserProvider);
    final canPost = user?.userType.isShopper ?? true;

    return Scaffold(
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () => showPostWantSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Post a want'),
            )
          : null,
      body: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: CategoryChips(
              selected: category,
              onSelected: (c) =>
                  ref.read(browseCategoryProvider.notifier).state = c,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.pullToRefresh(feedProvider(query).future),
              child: AsyncValueView(
                value: feed,
                onRetry: () => ref.invalidate(feedProvider(query)),
                loading: (_) => const FeedSkeleton(),
                data: (items) {
                  if (items.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.explore_off_outlined,
                          title: 'Nothing here yet',
                          message:
                              'No trips or wants match this filter. Check back soon, '
                              'or post a want of your own.',
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
                      if (item.isTrip && item.trip != null) {
                        return TripFeedCard(
                          trip: item.trip!,
                          traveler: item.owner,
                          earnEstimate: item.earnEstimate,
                          matchCount: item.matchCount,
                          onTap: () => context.push('/trips/${item.trip!.id}'),
                        );
                      }
                      if (item.want != null) {
                        return WantFeedCard(
                          want: item.want!,
                          shopper: item.owner,
                          matchCount: item.matchCount,
                          onTap: () => context.push('/wants/${item.want!.id}'),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
