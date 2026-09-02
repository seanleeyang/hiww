import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/countries.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/status_pill.dart';
import '../data/wants_repository.dart';
import 'post_want_sheet.dart';

class MyWantsScreen extends ConsumerWidget {
  const MyWantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wants = ref.watch(myWantsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPostWantSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Post a want'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myWantsProvider),
        child: AsyncValueView(
          value: wants,
          onRetry: () => ref.invalidate(myWantsProvider),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.favorite_outline,
                  title: 'No wants yet',
                  message: 'Post what you want bought abroad and travelers will make offers.',
                  action: FilledButton(
                    onPressed: () => showPostWantSheet(context),
                    child: const Text('Post a want'),
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                          StatusPill(w.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 12, runSpacing: 4, children: [
                        IconLine(Icons.sell_outlined, 'Budget ${w.budgetLabel}'),
                        IconLine(Icons.public,
                            'Buy in ${w.sourceCity ?? countryName(w.sourceCountry)}'),
                        if (w.needByLabel != null)
                          IconLine(Icons.event_outlined, w.needByLabel!),
                      ]),
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
