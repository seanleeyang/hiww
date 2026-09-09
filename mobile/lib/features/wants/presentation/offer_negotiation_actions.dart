import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/offer.dart';

/// Accept / counter / decline controls for one offer's current price, shown
/// only when it's the viewer's turn to respond (`offer.myTurn`) — the other
/// side sees a waiting note instead. Counters are capped at 2 total; once
/// `canCounter` is false the only options left are accept or decline.
class OfferNegotiationActions extends StatefulWidget {
  const OfferNegotiationActions({
    super.key,
    required this.offer,
    required this.enabled,
    required this.onAccept,
    required this.onCounter,
    required this.onReject,
  });

  final Offer offer;

  /// Additional gate beyond the server's `myTurn` — e.g. the want having
  /// since closed via a different offer.
  final bool enabled;
  final Future<void> Function() onAccept;
  final Future<void> Function(String price) onCounter;
  final Future<void> Function() onReject;

  @override
  State<OfferNegotiationActions> createState() => _OfferNegotiationActionsState();
}

class _OfferNegotiationActionsState extends State<OfferNegotiationActions> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCounterDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: widget.offer.quotedPrice);
    final price = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.dialogCounterOfferTitle),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.fieldYourPrice, prefixText: '฿ '),
          autofocus: true,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () {
                  final v = double.tryParse(controller.text.trim());
                  if (v == null || v <= 0) return;
                  Navigator.pop(dialogContext, v.toStringAsFixed(2));
                },
                child: Text(l10n.actionSubmit),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.actionCancel)),
            ],
          ),
        ],
      ),
    );
    if (price != null) await _run(() => widget.onCounter(price));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final o = widget.offer;
    if (o.status != 'pending') return const SizedBox.shrink();

    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13);

    if (!o.myTurn || !widget.enabled) {
      final waitingLabel = widget.enabled
          ? (o.respondBy != null
              ? l10n.waitingForResponseWithCountdown(countdown(o.respondBy))
              : l10n.waitingForResponse)
          : l10n.wantNoLongerOpen;
      return Row(
        children: [
          Icon(Icons.hourglass_empty, size: 16, color: muted.color),
          const SizedBox(width: 6),
          Text(waitingLabel, style: muted),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (o.respondBy != null) ...[
          Text(l10n.respondWithin(countdown(o.respondBy)), style: muted),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _run(widget.onAccept),
                child: Text(l10n.actionAcceptPrice(o.priceLabel)),
              ),
            ),
            const SizedBox(width: 8),
            if (o.canCounter)
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _showCounterDialog,
                  child: Text(l10n.actionCounter),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => _run(widget.onReject),
          child: Text(o.canCounter ? l10n.actionDecline : l10n.actionDeclineFinalOffer),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
          ),
      ],
    );
  }
}
