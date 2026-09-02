import 'package:intl/intl.dart';

final _dayMonth = DateFormat('MMM d');
final _monthDayYear = DateFormat('MMM d, y');

/// `฿1,500` / `฿1,234.56` — the backend stores amounts as decimal strings.
String money(Object? amount) {
  final value = switch (amount) {
    num n => n.toDouble(),
    String s => double.tryParse(s) ?? 0,
    _ => 0.0,
  };
  final f = NumberFormat.decimalPattern('en_US');
  if (value == value.roundToDouble()) {
    f.maximumFractionDigits = 0;
  } else {
    f.minimumFractionDigits = 2;
    f.maximumFractionDigits = 2;
  }
  return '฿${f.format(value)}';
}

/// `Nov 12–19` (same month) / `Nov 28 – Dec 3` / single date `Nov 12`.
String dateRange(DateTime? start, DateTime? end) {
  if (start == null && end == null) return '';
  if (start == null) return _dayMonth.format(end!);
  if (end == null) return _dayMonth.format(start);
  if (start.year == end.year && start.month == end.month) {
    return '${_dayMonth.format(start)}–${end.day}';
  }
  return '${_dayMonth.format(start)} – ${_dayMonth.format(end)}';
}

String dateLong(DateTime? d) => d == null ? '' : _monthDayYear.format(d);

/// `Nov 14` for a stepper timestamp.
String shortDate(DateTime? d) => d == null ? '' : _dayMonth.format(d);

DateTime? parseDate(Object? raw) {
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw)?.toLocal();
  return null;
}

/// `AL` from `Ada Lovelace`, `H` from `Hiww`.
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

String pluralize(int n, String singular, [String? plural]) =>
    n == 1 ? '1 $singular' : '$n ${plural ?? '${singular}s'}';
