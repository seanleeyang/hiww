import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/hero_image.dart';
import '../../../ui/image_picker_field.dart';
import '../../../ui/responsive_body.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/star_rating.dart';
import '../../../ui/stock_images.dart';
import '../../discovery/data/discovery_repository.dart';
import '../../shared/data/reviews_repository.dart';
import '../data/orders_repository.dart';

class ConfirmReviewScreen extends ConsumerStatefulWidget {
  const ConfirmReviewScreen({
    super.key,
    required this.orderId,
    this.reviewOnly = false,
  });

  final String orderId;

  /// When true the order is already delivered — just collect a rating.
  final bool reviewOnly;

  @override
  ConsumerState<ConfirmReviewScreen> createState() =>
      _ConfirmReviewScreenState();
}

class _ConfirmReviewScreenState extends ConsumerState<ConfirmReviewScreen> {
  final _comment = TextEditingController();
  int _rating = 5;
  String? _deliveryPhotoUrl;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit(String counterpartyId) async {
    final l10n = AppLocalizations.of(context)!;
    if (_rating < 1) {
      setState(() => _error = l10n.errorTapStarToRate);
      return;
    }
    if (!widget.reviewOnly && _deliveryPhotoUrl == null) {
      setState(() => _error = l10n.errorDeliveryPhotoRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final orders = ref.read(ordersRepositoryProvider);
      if (!widget.reviewOnly) {
        await orders.confirmReceived(widget.orderId, imageUrl: _deliveryPhotoUrl!);
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.reviewOnly
                ? l10n.infoThanksForReview
                : l10n.infoPaymentReleased,
          ),
        ),
      );
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
      appBar: AppBar(
        title: Text(widget.reviewOnly ? l10n.leaveReviewTitle : l10n.confirmAndReviewTitle),
      ),
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
                if (!widget.reviewOnly) ...[
                  const SizedBox(height: 20),
                  Text(l10n.labelDeliveryProof, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    l10n.hintDeliveryProofRequired,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ImagePickerField(
                    value: _deliveryPhotoUrl,
                    label: _busy ? l10n.actionUploading : l10n.actionUploadDeliveryPhoto,
                    onChanged: (url) => setState(() => _deliveryPhotoUrl = url),
                  ),
                ],
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
                      : () => _submit(o.counterparty?.id ?? ''),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.reviewOnly
                              ? l10n.actionSubmitReview
                              : l10n.actionConfirmRelease(o.totalLabel),
                        ),
                ),
                if (!widget.reviewOnly) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.releaseNoteToName(name),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
