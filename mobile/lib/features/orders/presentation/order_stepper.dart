import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../theme/app_colors.dart';
import '../domain/order.dart';

class _Stage {
  const _Stage(this.title, this.hint, this.at);
  final String title;
  final String hint;
  final DateTime? at;
}

/// The vertical, dated progress tracker from the mockup.
class OrderStepper extends StatelessWidget {
  const OrderStepper({super.key, required this.order});

  final Order order;

  // Index of the stage the order is currently *at*. `delivered` returns one
  // past the last stage so every dot — including "Delivered" — renders as a
  // completed green tick once the order is done.
  int get _reached => switch (order.status) {
        'pending_payment' => 0,
        'confirmed' => 1,
        'purchased' => 2,
        'in_transit' => 3,
        'delivered' => 5,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hiww = context.hiww;

    final stages = <_Stage>[
      _Stage('Accepted', 'Offer accepted', order.createdAt),
      _Stage('Paid', 'Payment confirmed', order.confirmedAt),
      _Stage('Bought', 'Traveler bought the item', order.purchasedAt),
      _Stage('In transit', 'On the way to you', order.shippedAt),
      _Stage('Delivered', 'Confirm to release payment', order.deliveredAt),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stages.length; i++)
          _row(context, stages[i], i, isLast: i == stages.length - 1, scheme: scheme, hiww: hiww),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    _Stage stage,
    int index, {
    required bool isLast,
    required ColorScheme scheme,
    required HiwwColors hiww,
  }) {
    final done = index < _reached;
    final current = index == _reached;
    final dotColor = done
        ? hiww.success
        : current
            ? scheme.primary
            : scheme.outlineVariant;
    final lineColor = index < _reached ? hiww.success : scheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: done ? dotColor : scheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: done
                    ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                    : current
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration:
                                  BoxDecoration(color: dotColor, shape: BoxShape.circle),
                            ),
                          )
                        : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: lineColor),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: (done || current) ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stage.at != null ? shortDate(stage.at) : stage.hint,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
