import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/countries.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/status_pill.dart';
import '../../orders/data/orders_repository.dart';
import '../data/wants_repository.dart';
import 'post_want_sheet.dart';

const _archivableStatuses = {'cancelled', 'completed'};

Future<void> _archiveWant(BuildContext context, WidgetRef ref, String wantId) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    // Shadow `context` with the dialog's own — using the caller's context to
    // pop here would pop the tab's own nested navigator instead of just
    // dismissing the dialog, since this screen lives inside the bottom-tab
    // shell, not on the root navigator.
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
    await ref.read(wantsRepositoryProvider).archive(wantId);
    ref.invalidate(myWantsProvider);
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class MyWantsScreen extends ConsumerWidget {
  const MyWantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final wants = ref.watch(myWantsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPostWantSheet(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.actionPostAWant),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.pullToRefresh(myWantsProvider.future),
        child: AsyncValueView(
          value: wants,
          onRetry: () => ref.invalidate(myWantsProvider),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.favorite_outline,
                  title: l10n.emptyMyWantsTitle,
                  message: l10n.emptyMyWantsMessage,
                  action: FilledButton(
                    onPressed: () => showPostWantSheet(context),
                    child: Text(l10n.actionPostAWant),
                  ),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final w = list[i];
                final orderId = ref
                    .watch(orderIdByRequestProvider)
                    .maybeWhen(data: (m) => m[w.id], orElse: () => null);
                return SoftCard(
                  onTap: orderId != null
                      ? () => context.push('/orders/$orderId')
                      : () => context.push('/wants/${w.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(w.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                          StatusPill(w.status),
                          if (_archivableStatuses.contains(w.status)) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: l10n.tooltipRemoveFromList,
                              onPressed: () => _archiveWant(context, ref, w.id),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 12, runSpacing: 4, children: [
                        IconLine(Icons.sell_outlined, l10n.wantBudgetLine(w.budgetLabel)),
                        IconLine(Icons.public,
                            l10n.wantBuyInLine(w.sourceCity ?? countryName(w.sourceCountry))),
                        if (w.needByLabel != null)
                          IconLine(Icons.event_outlined, w.needByLabel!),
                      ]),
                      if (orderId != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(l10n.actionViewOrder,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
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
