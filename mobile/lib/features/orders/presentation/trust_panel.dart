import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../ui/soft_card.dart';
import '../domain/order.dart';

/// "Hiww is holding ฿X + ฿Y fee — released when you confirm delivery" +
/// a How-it-works sheet that is honest about the manual-money pilot.
class TrustPanel extends StatelessWidget {
  const TrustPanel({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hiww = context.hiww;
    final released = order.status == 'delivered';

    return SoftCard(
      color: hiww.infoSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(released ? Icons.verified_outlined : Icons.lock_outline,
                  size: 18, color: hiww.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  released
                      ? 'Released — ${order.totalLabel} to the traveler'
                      : 'Hiww is holding ${order.totalLabel} + ${order.feesLabel} fee',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            released
                ? 'Payment for these goods has been settled.'
                : 'Released to the traveler when you confirm you have the item.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _showHowItWorks(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('How payment protection works'),
            ),
          ),
        ],
      ),
    );
  }

  void _showHowItWorks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How payment protection works',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _step(context, '1', 'You pay Hiww when you accept an offer.'),
              _step(context, '2',
                  'Hiww holds the money — the traveler is not paid yet.'),
              _step(context, '3', 'The traveler buys and ships your item.'),
              _step(context, '4',
                  'You confirm you received it, and Hiww releases the payment.'),
              const SizedBox(height: 12),
              Text(
                'During the pilot, Hiww settles payments by hand rather than through '
                'a card processor. If something goes wrong, use "Report a problem" '
                'and the Hiww team will step in before any money moves.',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(BuildContext context, String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(n,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
