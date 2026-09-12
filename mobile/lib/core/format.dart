import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

final _dayMonth = DateFormat('MMM d');
final _monthDayYear = DateFormat('MMM d, y');
final _dayMonthTime = DateFormat('MMM d, h:mm a');
final _timeOnly = DateFormat('h:mm a');
final _dMmmY = DateFormat('d MMM y');

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

/// `Earn ฿80–1,200` (per-item commission range) / `Earn ฿520` when every
/// matched want pays the same. Never a sum — a trip can't fulfil every
/// matched want at once, so a total would overstate what's achievable.
String earnRangeLabel(AppLocalizations l10n, Object? min, Object? max) {
  final lo = money(min);
  final hi = money(max);
  if (lo == hi) return l10n.earnSingle(lo);
  final hiBare = hi.startsWith('฿') ? hi.substring(1) : hi;
  return l10n.earnRange(lo, hiBare);
}

/// `12 Nov 2026 – 19 Nov 2026` / single date `12 Nov 2026`. The separator is
/// a symbol rather than the word "to" so this needs no translation; the
/// month abbreviation itself is intentionally left in Gregorian/English
/// form even in Thai — full Thai-calendar dates (Buddhist Era year, Thai
/// month names) are a materially bigger, separate feature, not attempted
/// here.
String dateRange(DateTime? start, DateTime? end) {
  if (start == null && end == null) return '';
  if (start == null) return _dMmmY.format(end!);
  if (end == null) return _dMmmY.format(start);
  return '${_dMmmY.format(start)} – ${_dMmmY.format(end)}';
}

String dateLong(DateTime? d) => d == null ? '' : _monthDayYear.format(d);

/// `Nov 14` for a stepper timestamp.
String shortDate(DateTime? d) => d == null ? '' : _dayMonth.format(d);

/// `2:30 PM` for a message sent today, `Sep 6, 2:30 PM` otherwise.
String chatTimestamp(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  final sameDay =
      d.year == now.year && d.month == now.month && d.day == now.day;
  return sameDay ? _timeOnly.format(d) : _dayMonthTime.format(d);
}

DateTime? parseDate(Object? raw) {
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw)?.toLocal();
  return null;
}

/// `AL` from `Ada Lovelace`, `H` from `Hiww`.
String initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

String pluralize(int n, String singular, [String? plural]) =>
    n == 1 ? '1 $singular' : '$n ${plural ?? '${singular}s'}';

/// `just now` / `5m` / `3h` / `2d` / `Nov 14` — compact relative time for
/// feeds. The `m`/`h`/`d` unit letters are left as universal shorthand
/// (not translated) — that matches how compact relative-time is commonly
/// shown even in localized apps, and a full Thai equivalent would be no
/// more compact or readable.
String timeAgo(AppLocalizations l10n, DateTime? d, {DateTime? now}) {
  if (d == null) return '';
  final delta = (now ?? DateTime.now()).difference(d);
  if (delta.inSeconds < 45) return l10n.timeJustNow;
  if (delta.inMinutes < 60) return '${delta.inMinutes}m';
  if (delta.inHours < 24) return '${delta.inHours}h';
  if (delta.inDays < 7) return '${delta.inDays}d';
  return _dayMonth.format(d);
}

/// `42m left` / `1h 5m left` / `Expired` — countdown to a future deadline
/// (e.g. an order's payment window).
String countdown(AppLocalizations l10n, DateTime? deadline, {DateTime? now}) {
  if (deadline == null) return '';
  final remaining = deadline.difference(now ?? DateTime.now());
  if (remaining.isNegative) return l10n.timeExpired;
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  if (hours > 0) return l10n.timeHoursMinutesLeft(hours, minutes);
  if (minutes > 0) return l10n.timeMinutesLeft(minutes);
  return l10n.timeLessThanMinuteLeft;
}
