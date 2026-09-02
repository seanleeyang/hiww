import 'package:flutter/material.dart';

import '../core/format.dart';

/// "− ฿6,500 +" stepper. Value is whole baht.
class BudgetStepper extends StatelessWidget {
  const BudgetStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 500,
    this.min = 0,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int step;
  final int min;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value - step >= min ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Text(
              money(value),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + step),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
