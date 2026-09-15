import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// A row of single-digit boxes for entering an OTP code: typing a digit
/// advances to the next box, Backspace from an empty box steps back and
/// clears the previous one, the arrow keys move focus directly, and pasting
/// a full code spreads it across the boxes starting from wherever the paste
/// landed. Non-digit characters are stripped everywhere.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    required this.onChanged,
    this.length = 6,
    this.enabled = true,
  });

  final int length;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<OtpCodeInput> createState() => OtpCodeInputState();
}

class OtpCodeInputState extends State<OtpCodeInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  /// Fills every box from a code the app already knows (e.g. the dev-mode
  /// OTP hint) — the same spread a paste of that string would produce.
  void setCode(String code) => _fill(0, code);

  void _fill(int startIndex, String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    var index = startIndex;
    for (var i = 0; i < digits.length && index < widget.length; i++, index++) {
      _controllers[index].text = digits[i];
    }
    final lastFilled = index - 1;
    if (lastFilled >= 0 && lastFilled < widget.length - 1) {
      _focusNodes[lastFilled + 1].requestFocus();
    } else if (lastFilled == widget.length - 1) {
      _focusNodes[lastFilled].unfocus();
    }
    setState(() {});
    widget.onChanged(_code);
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // More than one character landed in a single box — a paste (or fast
      // IME commit) rather than a typed digit. Spread it from here instead
      // of keeping it bunched in one box.
      _fill(index, value);
      return;
    }
    if (value.isEmpty) return; // Backspace is handled via the key handler below.
    _controllers[index].text = value;
    if (index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }
    setState(() {});
    widget.onChanged(_code);
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isNotEmpty) {
      _controllers[index].clear();
      setState(() {});
      widget.onChanged(_code);
      return;
    }
    if (index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
      widget.onChanged(_code);
    }
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      _onBackspace(index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index > 0) _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < widget.length - 1) _focusNodes[index + 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hairline = context.hiww.hairline;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(HiwwRadii.input),
      borderSide: BorderSide(color: hairline),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(HiwwRadii.input),
      borderSide: BorderSide(color: scheme.primary, width: 2),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return SizedBox(
          width: 48,
          height: 48,
          child: Focus(
            onKeyEvent: (node, event) => _onKey(index, event),
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              enabled: widget.enabled,
              autofocus: index == 0,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
              keyboardType: TextInputType.number,
              // Not capped at 1: a paste can land its whole run of digits in
              // whichever box catches focus, and _onDigitChanged splits it
              // back out. Capping here would let maxLength silently drop the
              // rest of a pasted code before onChanged ever sees it.
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: scheme.surface,
                border: border,
                enabledBorder: border,
                focusedBorder: focusedBorder,
              ),
              onChanged: (value) => _onDigitChanged(index, value),
            ),
          ),
        );
      }),
    );
  }
}
