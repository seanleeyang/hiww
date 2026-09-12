import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/offer.dart';

/// Accept / counter / decline controls for one offer's current price, shown
/// only when it's the viewer's turn to respond (`offer.myTurn`) — the other
/// side sees a waiting note instead. Counters are capped at 2 total; once
/// `canCounter` is false the only options left are accept or decline.
///
/// Also renders the offer's price history as a read-only, chat-styled
/// timeline above the controls: there's no real messaging thread for a
/// negotiation (chat only opens once an order exists), so this is the
/// closest thing to "seeing the back-and-forth" until then.
class OfferNegotiationActions extends StatefulWidget {
  const OfferNegotiationActions({
    super.key,
    required this.offer,
    required this.myRole,
    required this.enabled,
    required this.onAccept,
    required this.onCounter,
    required this.onReject,
  });

  final Offer offer;

  /// Which side the viewer is playing — 'shopper' or 'traveler' — used to
  /// align the price-history bubbles ("mine" on the right, matching the
  /// order chat's own bubble convention).
  final String myRole;

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
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Ticks the "respond within"/"waiting" countdown text live rather than
    // only updating on the next full refresh — purely visual, the actual
    // expiry only ever happens server-side (see offer-expiry.ts).
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.offer.respondBy != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

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
    String? error;
    final price = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(l10n.dialogCounterOfferTitle),
            content: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.fieldYourPrice,
                prefixText: '฿ ',
                errorText: error,
              ),
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
                      if (v == null || v <= 0) {
                        setDialogState(() => error = l10n.errorEnterValidPrice);
                        return;
                      }
                      Navigator.pop(dialogContext, v.toStringAsFixed(2));
                    },
                    child: Text(l10n.actionSubmit),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.actionCancel)),
                ],
              ),
            ],
          );
        },
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
    final history = o.priceHistory.isEmpty
        ? null
        : _OfferHistoryTimeline(history: o.priceHistory, myRole: widget.myRole);

    if (!o.myTurn || !widget.enabled) {
      final waitingLabel = widget.enabled
          ? (o.respondBy != null
              ? l10n.waitingForResponseWithCountdown(countdown(l10n, o.respondBy))
              : l10n.waitingForResponse)
          : l10n.wantNoLongerOpen;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (history != null) ...[history, const SizedBox(height: 8)],
          Row(
            children: [
              Icon(Icons.hourglass_empty, size: 16, color: muted.color),
              const SizedBox(width: 6),
              Text(waitingLabel, style: muted),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (history != null) ...[history, const SizedBox(height: 8)],
        if (o.respondBy != null) ...[
          Text(l10n.respondWithin(countdown(l10n, o.respondBy)), style: muted),
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

/// Read-only, chat-styled record of an offer's price history. Round 0 is
/// always the traveler's opening price; every entry after that is a counter
/// from whichever side didn't propose the current price.
class _OfferHistoryTimeline extends StatelessWidget {
  const _OfferHistoryTimeline({required this.history, required this.myRole});

  final List<PriceHistoryEntry> history;
  final String myRole;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < history.length; i++)
          _HistoryBubble(
            entry: history[i],
            mine: history[i].by == myRole,
            label: i == 0
                ? l10n.offerHistoryOffered(money(history[i].price))
                : l10n.offerHistoryCountered(money(history[i].price)),
          ),
      ],
    );
  }
}

/// Styled to match `OrderChatScreen`'s `_Bubble` — same shape, same
/// timestamp treatment — so this genuinely reads as "the chat" for a
/// negotiation that doesn't have a real messaging thread yet.
class _HistoryBubble extends StatelessWidget {
  const _HistoryBubble({required this.entry, required this.mine, required this.label});

  final PriceHistoryEntry entry;
  final bool mine;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: mine ? scheme.onPrimary : scheme.onSurface)),
            if (entry.at != null) ...[
              const SizedBox(height: 3),
              Text(
                chatTimestamp(l10n, entry.at),
                style: TextStyle(
                  fontSize: 10,
                  color: (mine ? scheme.onPrimary : scheme.onSurfaceVariant).withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
