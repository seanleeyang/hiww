import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';

/// A full-screen bottom sheet: a scrolling multi-month calendar for picking
/// a departure/return date range, with the selected range highlighted.
/// Returns `(start, end)`, or null if dismissed without a complete pick.
Future<(DateTime, DateTime)?> showDateRangeSheet(
  BuildContext context, {
  DateTime? initialStart,
  DateTime? initialEnd,
}) {
  return showModalBottomSheet<(DateTime, DateTime)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DateRangeSheet(initialStart: initialStart, initialEnd: initialEnd),
  );
}

class _DateRangeSheet extends StatefulWidget {
  const _DateRangeSheet({this.initialStart, this.initialEnd});
  final DateTime? initialStart;
  final DateTime? initialEnd;

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  late DateTime? _start = widget.initialStart;
  late DateTime? _end = widget.initialEnd;

  // 13 months from "now" (this month through next year) is enough runway
  // for the ~1-year trip window the rest of the app already allows
  // (NewTripScreen's own showDatePicker uses the same 365-day horizon).
  late final _firstMonth = DateTime(DateTime.now().year, DateTime.now().month);
  static const _monthCount = 13;

  void _tapDay(DateTime day) {
    setState(() {
      if (_start == null || (_end != null)) {
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _start = day;
      } else if (day.isAtSameMomentAs(_start!)) {
        // no-op: a single-day tap needs a second tap to form a range
      } else {
        _end = day;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    l10n.labelTravelDates,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          const _WeekdayHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _monthCount,
              itemBuilder: (context, i) {
                final month = DateTime(_firstMonth.year, _firstMonth.month + i);
                return _MonthGrid(
                  month: month,
                  start: _start,
                  end: _end,
                  onTapDay: _tapDay,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_start != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _end != null
                            ? '${shortDate(_start)} – ${shortDate(_end)}'
                            : shortDate(_start),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  FilledButton(
                    onPressed: (_start != null && _end != null)
                        ? () => Navigator.of(context).pop((_start!, _end!))
                        : null,
                    child: Text(l10n.actionDone),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = AppLocalizations.of(context)!.localeName;
    // DateTime.weekday is 1=Mon..7=Sun; start the header on Sunday to match
    // the grid below, which lays out Sunday-first weeks. 2024-01-07 was a
    // Sunday, used here purely as a reference date to format weekday names.
    final labels = [
      for (var i = 0; i < 7; i++)
        DateFormat('E', locale).format(DateTime(2024, 1, 7 + i)).toUpperCase(),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          for (final l in labels)
            Expanded(
              child: Text(
                l,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.start,
    required this.end,
    required this.onTapDay,
  });

  final DateTime month;
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onTapDay;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = AppLocalizations.of(context)!.localeName;
    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday: 1=Mon..7=Sun -> convert to 0=Sun..6=Sat leading blanks.
    final leadingBlanks = firstOfMonth.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            DateFormat('MMMM y', locale).format(month),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++) ...[
                Builder(builder: (context) {
                  final cellIndex = r * 7 + c;
                  final dayNum = cellIndex - leadingBlanks + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 44));
                  }
                  final day = DateTime(month.year, month.month, dayNum);
                  final disabled = day.isBefore(todayMidnight);
                  final isStart = start != null && _sameDay(day, start!);
                  final isEnd = end != null && _sameDay(day, end!);
                  final inRange = start != null &&
                      end != null &&
                      day.isAfter(start!) &&
                      day.isBefore(end!);

                  return Expanded(
                    child: SizedBox(
                      height: 44,
                      child: Stack(
                        children: [
                          if (inRange || (isEnd) || (isStart && end != null))
                            // Matches the day circle's own height (36) —
                            // filling the full 44-tall cell here left the
                            // band's flat top/bottom edges poking out past
                            // the circle's curve at the start/end days,
                            // where the band only covers half the width.
                            Positioned.fill(
                              child: Center(
                                child: SizedBox(
                                  height: 36,
                                  child: Row(
                                    children: [
                                      if (!isStart)
                                        Expanded(child: Container(color: scheme.primaryContainer)),
                                      if (isStart) const Spacer(),
                                      if (!isEnd)
                                        Expanded(child: Container(color: scheme.primaryContainer))
                                      else
                                        const Spacer(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Center(
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: disabled ? null : () => onTapDay(day),
                              child: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (isStart || isEnd) ? scheme.primary : null,
                                ),
                                child: Text(
                                  '$dayNum',
                                  style: TextStyle(
                                    color: disabled
                                        ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                                        : (isStart || isEnd)
                                            ? scheme.onPrimary
                                            : scheme.onSurface,
                                    fontWeight: (isStart || isEnd) ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
      ],
    );
  }
}
