import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/hero_image.dart';
import '../../../ui/responsive_body.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/star_rating.dart';
import '../../../ui/stock_images.dart';
import '../../discovery/data/discovery_repository.dart';
import '../../shared/data/reviews_repository.dart';
import '../data/orders_repository.dart';

/// Just the rating/review step — payment release (with its required
/// proof-of-receipt photo) already happened on the order screen before
/// this pushes, so there's nothing left to confirm here.
class ConfirmReviewScreen extends ConsumerStatefulWidget {
  const ConfirmReviewScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ConfirmReviewScreen> createState() =>
      _ConfirmReviewScreenState();
}

class _ConfirmReviewScreenState extends ConsumerState<ConfirmReviewScreen> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _close(String counterpartyId) async {
    final l10n = AppLocalizations.of(context)!;
    if (_rating < 1) {
      setState(() => _error = l10n.errorTapStarToRate);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(reviewsRepositoryProvider)
          .submit(
            widget.orderId,
            rating: _rating,
            comment: _comment.text.trim(),
          );
      ref.invalidate(orderProvider(widget.orderId));
      ref.invalidate(myOrdersProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(userReviewsProvider(counterpartyId));
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.infoThanksForReview)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final order = ref.watch(orderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaveReviewTitle)),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: order,
          onRetry: () => ref.invalidate(orderProvider(widget.orderId)),
          data: (o) {
            final name = o.counterparty?.fullName ?? l10n.fallbackTheTraveler;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                HeroImage(
                  url: o.requestImageUrl,
                  fallbackAsset: stockForCategory(o.requestCategory),
                  height: 170,
                  enableFullscreen: true,
                ),
                const SizedBox(height: 14),
                SoftCard(
                  child: Row(
                    children: [
                      Expanded(child: Text(o.itemDescription)),
                      const SizedBox(width: 8),
                      Text(
                        o.totalLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.howWasName(name),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                StarRatingInput(
                  value: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _comment,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n.hintShareHandover,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _close(o.counterparty?.id ?? ''),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.actionClose),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
