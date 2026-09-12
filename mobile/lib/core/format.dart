import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

// Locale only changes which language the month/day names render in (Thai
// month abbreviations etc., via CLDR data loaded by `initializeDateFormatting`
// in main.dart) — the year is always whatever `DateTime.year` already is
// (Gregorian), never converted to the Buddhist Era. `DateFormat` is cheap to
// construct, so these are built fresh per call rather than cached per locale.
DateFormat _dayMonth(String locale) => DateFormat('MMM d', locale);
DateFormat _monthDayYear(String locale) => DateFormat('MMM d, y', locale);
DateFormat _dayMonthTime(String locale) => DateFormat('MMM d, h:mm a', locale);
DateFormat _timeOnly(String locale) => DateFormat('h:mm a', locale);
DateFormat _dMmmY(String locale) => DateFormat('d MMM y', locale);

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

/// `12 พ.ย. 2026 – 19 พ.ย. 2026` / single date `12 พ.ย. 2026` (or the English
/// month form outside Thai locale). The separator is a symbol rather than
/// the word "to" so it needs no translation on its own. The year is always
/// whatever `DateTime.year` already is — Gregorian, never converted to the
/// Buddhist Era — only the month/day names switch language.
String dateRange(AppLocalizations l10n, DateTime? start, DateTime? end) {
  final fmt = _dMmmY(l10n.localeName);
  if (start == null && end == null) return '';
  if (start == null) return fmt.format(end!);
  if (end == null) return fmt.format(start);
  return '${fmt.format(start)} – ${fmt.format(end)}';
}

String dateLong(AppLocalizations l10n, DateTime? d) =>
    d == null ? '' : _monthDayYear(l10n.localeName).format(d);

/// `20-05-1998` — fixed DD-MM-YYYY, used for personal-details dates (date of
/// birth) regardless of system language. There's no month name here to
/// translate, so unlike the locale-aware formats above this is always the
/// same numeric ordering — the user's stated preference for any date field
/// of this kind.
String ddMmYyyy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year.toString().padLeft(4, '0')}';

/// `Nov 14` for a stepper timestamp.
String shortDate(AppLocalizations l10n, DateTime? d) =>
    d == null ? '' : _dayMonth(l10n.localeName).format(d);

/// `2:30 PM` for a message sent today, `Sep 6, 2:30 PM` otherwise.
String chatTimestamp(AppLocalizations l10n, DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  final sameDay =
      d.year == now.year && d.month == now.month && d.day == now.day;
  final locale = l10n.localeName;
  return sameDay ? _timeOnly(locale).format(d) : _dayMonthTime(locale).format(d);
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

/// `just now` / `5m` / `3h` / `2d` (or the Thai equivalents) / `Nov 14` —
/// compact relative time for feeds.
String timeAgo(AppLocalizations l10n, DateTime? d, {DateTime? now}) {
  if (d == null) return '';
  final delta = (now ?? DateTime.now()).difference(d);
  if (delta.inSeconds < 45) return l10n.timeJustNow;
  if (delta.inMinutes < 60) return l10n.timeMinutesShort(delta.inMinutes);
  if (delta.inHours < 24) return l10n.timeHoursShort(delta.inHours);
  if (delta.inDays < 7) return l10n.timeDaysShort(delta.inDays);
  return _dayMonth(l10n.localeName).format(d);
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
