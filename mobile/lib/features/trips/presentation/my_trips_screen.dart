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
import '../domain/trip.dart';

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

/// A trip is Active while it's still published and hasn't returned yet
/// (`status`/`in_progress`/`completed` are never actually set by the
/// backend — see `trips` migrations — so date + `cancelled` are the only
/// reliable signals); everything else — cancelled, or the return date has
/// passed — is Past.
bool _isActive(Trip t) =>
    t.status != 'cancelled' && (t.returnDate == null || t.returnDate!.isAfter(DateTime.now()));

/// Negotiations on a traveler's offers live on each want's own detail page
/// now, not nested here — this is trips only.
class MyTripsScreen extends ConsumerStatefulWidget {
  const MyTripsScreen({super.key});

  @override
  ConsumerState<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends ConsumerState<MyTripsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final trips = ref.watch(myTripsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trips/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.actionPostATrip),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.tripsTabActive),
              Tab(text: l10n.tripsTabPast),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.pullToRefresh(myTripsProvider.future),
              child: AsyncValueView(
                value: trips,
                onRetry: () => ref.invalidate(myTripsProvider),
                data: (list) {
                  final active = list.where(_isActive).toList();
                  final past = list.where((t) => !_isActive(t)).toList();
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _TripList(
                        trips: active,
                        emptyTitle: l10n.emptyMyTripsTitle,
                        emptyMessage: l10n.emptyMyTripsMessage,
                        emptyAction: FilledButton(
                          onPressed: () => context.push('/trips/new'),
                          child: Text(l10n.actionPostATrip),
                        ),
                      ),
                      _TripList(
                        trips: past,
                        emptyTitle: l10n.emptyTripsPastTitle,
                        emptyMessage: l10n.emptyTripsPastMessage,
                      ),
                    ],
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

class _TripList extends ConsumerWidget {
  const _TripList({
    required this.trips,
    required this.emptyTitle,
    required this.emptyMessage,
    this.emptyAction,
  });

  final List<Trip> trips;
  final String emptyTitle;
  final String emptyMessage;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (trips.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 70),
        EmptyState(icon: Icons.flight_outlined, title: emptyTitle, message: emptyMessage, action: emptyAction),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: trips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final t = trips[i];
        return SoftCard(
          onTap: () => context.push('/trips/${t.id}'),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title ?? t.route,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
  }
}
