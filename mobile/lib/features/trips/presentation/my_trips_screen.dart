import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/status_pill.dart';
import '../data/trips_repository.dart';

const _archivableStatuses = {'cancelled', 'completed'};

Future<void> _archiveTrip(BuildContext context, WidgetRef ref, String tripId) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    // Shadow `context` with the dialog's own — using the caller's context to
    // pop here would pop the tab's own nested navigator instead of just
    // dismissing the dialog, since this screen lives inside the bottom-tab
    // shell, not on the root navigator.
    builder: (context) => AlertDialog(
      title: Text(l10n.dialogRemoveTripTitle),
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
          OutlinedButton(
            onPressed: () => context.pop(false),
            child: Text(l10n.actionCancel),
          ),
        ],
      ),
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
    final l10n = AppLocalizations.of(context)!;
    final trips = ref.watch(myTripsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trips/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.actionPostATrip),
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
                  title: l10n.emptyMyTripsTitle,
                  message: l10n.emptyMyTripsMessage,
                  action: FilledButton(
                    onPressed: () => context.push('/trips/new'),
                    child: Text(l10n.actionPostATrip),
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
                          tooltip: l10n.tooltipRemoveFromList,
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
