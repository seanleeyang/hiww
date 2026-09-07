import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/status_pill.dart';
import '../data/trips_repository.dart';

const _archivableStatuses = {'cancelled', 'completed'};

Future<void> _archiveTrip(BuildContext context, WidgetRef ref, String tripId) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Remove this trip?'),
      content: const Text('It disappears from your list. This does not affect its history.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(tripsRepositoryProvider).archive(tripId);
    ref.invalidate(myTripsProvider);
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Negotiations on a traveler's offers live in the unified Offers tab
/// (`offers_screen.dart`), not nested here — this is trips only.
class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(myTripsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trips/new'),
        icon: const Icon(Icons.add),
        label: const Text('Post a trip'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.pullToRefresh(myTripsProvider.future),
        child: AsyncValueView(
          value: trips,
          onRetry: () => ref.invalidate(myTripsProvider),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 70),
                EmptyState(
                  icon: Icons.flight_outlined,
                  title: 'No trips yet',
                  message: 'Post a trip and shoppers can request items along your route.',
                  action: FilledButton(
                    onPressed: () => context.push('/trips/new'),
                    child: const Text('Post a trip'),
                  ),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final t = list[i];
                return SoftCard(
                  onTap: () => context.push('/trips/${t.id}'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title ?? t.route,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 6),
                            RouteChip(route: t.route, dates: t.dates),
                          ],
                        ),
                      ),
                      StatusPill(t.status),
                      if (_archivableStatuses.contains(t.status)) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Remove from your list',
                          onPressed: () => _archiveTrip(context, ref, t.id),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
