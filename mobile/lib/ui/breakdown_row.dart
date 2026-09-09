import 'package:flutter/material.dart';

/// A "label ... amount" row for an itemized price/payout breakdown, shared
/// by the accept-offer confirmation and the order screen's money card.
class BreakdownRow extends StatelessWidget {
  const BreakdownRow(this.label, this.amount, {super.key, this.bold = false});
  final String label;
  final String amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w700) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(amount, style: style),
        ],
      ),
    );
  }
}
