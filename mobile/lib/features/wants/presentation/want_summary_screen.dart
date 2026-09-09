import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/countries.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/soft_card.dart';
import '../../discovery/data/discovery_repository.dart';
import '../data/wants_repository.dart';
import '../domain/want_draft.dart';

/// Step 2 of creating a want: review everything entered on
/// [CreateOrderScreen] before the actual `POST /api/requests` call.
class WantSummaryScreen extends ConsumerStatefulWidget {
  const WantSummaryScreen({super.key, required this.draft});
  final WantDraft draft;

  @override
  ConsumerState<WantSummaryScreen> createState() => _WantSummaryScreenState();
}

class _WantSummaryScreenState extends ConsumerState<WantSummaryScreen> {
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    final draft = widget.draft;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final id = await ref.read(wantsRepositoryProvider).create(
            title: draft.title,
            itemDescription: draft.itemDescription,
            sourceCountry: draft.sourceCountry,
            sourceCity: draft.sourceCity,
            category: draft.category,
            estimatedWeightKg: 1,
            budget: '${draft.budget.toStringAsFixed(0)}.00',
            quantity: draft.quantity,
            needBy: draft.needBy,
            imageUrl: draft.imageUrl,
            targetTripId: draft.targetTripId,
            destinationCountry: draft.destinationCountry,
            destinationCity: draft.destinationCity,
            productUrl: draft.productUrl,
          );
      ref.invalidate(myWantsProvider);
      ref.invalidate(feedProvider);
      if (!mounted) return;
      context.pop(); // Summary
      context.pop(); // Create Order
      context.push('/wants/$id');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final draft = widget.draft;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.summaryScreenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (draft.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        draft.imageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      draft.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (draft.isDirectRequest) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.directRequestNotice(draft.targetTravelerName ?? l10n.fallbackATraveler),
                          style: TextStyle(fontSize: 13, color: scheme.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (draft.productUrl != null) ...[
                      IconLine(Icons.link, l10n.wantProductUrlLine(draft.productUrl!)),
                      const SizedBox(height: 8),
                    ],
                    Text(draft.itemDescription),
                    const SizedBox(height: 10),
                    IconLine(Icons.category_outlined, draft.category),
                    const SizedBox(height: 6),
                    IconLine(Icons.numbers, l10n.wantQuantityLine(draft.quantity)),
                    const SizedBox(height: 6),
                    IconLine(
                      Icons.public,
                      l10n.wantBuyInLine(draft.sourceCity ?? countryName(draft.sourceCountry)),
                    ),
                    const SizedBox(height: 6),
                    IconLine(
                      Icons.local_shipping_outlined,
                      l10n.wantDeliverToLine(draft.destinationCity ?? countryName(draft.destinationCountry)),
                    ),
                    if (draft.needBy != null) ...[
                      const SizedBox(height: 6),
                      IconLine(Icons.event_outlined, 'Need by ${shortDate(draft.needBy)}'),
                    ],
                    const SizedBox(height: 6),
                    IconLine(Icons.sell_outlined, l10n.wantBudgetLine(money(draft.budget))),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(draft.isDirectRequest ? l10n.actionSendRequest : l10n.actionPostMyWant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
