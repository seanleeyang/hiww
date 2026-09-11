import 'package:flutter/services.dart';

/// Thailand's 13-digit national ID number is conventionally written with
/// hyphens grouped 1-4-5-2-1 (e.g. `1-2345-67890-12-3`). This strips
/// anything but digits, caps the result at 13 digits, and re-inserts the
/// hyphens as the user types.
String formatThaiNationalId(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '').characters13;
  final groups = <String>[];
  var i = 0;
  for (final len in const [1, 4, 5, 2, 1]) {
    if (i >= digits.length) break;
    final end = (i + len).clamp(0, digits.length);
    groups.add(digits.substring(i, end));
    i = end;
  }
  return groups.join('-');
}

extension on String {
  /// Truncates to 13 characters — named for clarity at the call site above.
  String get characters13 => length > 13 ? substring(0, 13) : this;
}

class ThaiNationalIdInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatThaiNationalId(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
