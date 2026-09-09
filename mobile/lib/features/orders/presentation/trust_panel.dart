import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
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
                      ? l10n.trustReleasedTo(order.travellerPayoutLabel ?? order.totalLabel)
                      : (order.hasPricingBreakdown
                          ? l10n.trustHoldingTotal(order.shopperTotalLabel!)
                          : l10n.trustHolding(order.totalLabel, order.feesLabel)),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            released ? l10n.trustSettled : l10n.trustReleasedOnConfirm,
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
              child: Text(l10n.actionHowProtectionWorks),
            ),
          ),
        ],
      ),
    );
  }

  void _showHowItWorks(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.actionHowProtectionWorks,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _step(context, '1', l10n.howProtectionStep1),
              _step(context, '2', l10n.howProtectionStep2),
              _step(context, '3', l10n.howProtectionStep3),
              _step(context, '4', l10n.howProtectionStep4),
              const SizedBox(height: 12),
              Text(
                l10n.howProtectionPilotNote,
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
