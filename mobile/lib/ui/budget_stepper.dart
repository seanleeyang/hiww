import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';

/// "− ฿6,500 +" stepper. Value is whole baht. Tap the amount to type an
/// exact value instead of stepping to it.
class BudgetStepper extends StatefulWidget {
  const BudgetStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 100,
    this.min = 0,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int step;
  final int min;

  @override
  State<BudgetStepper> createState() => _BudgetStepperState();
}

class _BudgetStepperState extends State<BudgetStepper> {
  final _focusNode = FocusNode();
  late final _controller = TextEditingController(text: widget.value.toString());
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant BudgetStepper old) {
    super.didUpdateWidget(old);
    if (!_editing && old.value != widget.value) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    _controller.text = widget.value.toString();
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text);
    setState(() => _editing = false);
    if (parsed != null && parsed >= widget.min) {
      widget.onChanged(parsed);
    } else {
      _controller.text = widget.value.toString();
    }
  }

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
            onPressed: widget.value - widget.step >= widget.min
                ? () => widget.onChanged(widget.value - widget.step)
                : null,
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: _editing
                ? TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _commit(),
                  )
                : InkWell(
                    onTap: _startEditing,
                    child: Text(
                      money(widget.value),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
          ),
          IconButton(
            onPressed: () => widget.onChanged(widget.value + widget.step),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
