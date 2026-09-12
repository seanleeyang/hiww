import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/core/format.dart';
import 'package:hiww_mobile/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('money', () {
    test('formats integer decimal strings without cents', () {
      expect(money('1500.00'), '฿1,500');
      expect(money('19200'), '฿19,200');
    });
    test('keeps cents when present', () {
      expect(money('1234.56'), '฿1,234.56');
    });
    test('handles nums and junk', () {
      expect(money(6500), '฿6,500');
      expect(money(null), '฿0');
      expect(money('abc'), '฿0');
    });
  });

  group('dateRange', () {
    test('spells out day, month and year on both ends', () {
      expect(
        dateRange(l10n, DateTime(2026, 11, 12), DateTime(2026, 11, 19)),
        '12 Nov 2026 – 19 Nov 2026',
      );
    });
    test('cross month shows both full dates', () {
      expect(
        dateRange(l10n, DateTime(2026, 11, 28), DateTime(2026, 12, 3)),
        '28 Nov 2026 – 3 Dec 2026',
      );
    });
    test('single date', () {
      expect(dateRange(l10n, DateTime(2026, 11, 12), null), '12 Nov 2026');
      expect(dateRange(l10n, null, null), '');
    });
  });

  group('ddMmYyyy', () {
    test('formats as fixed DD-MM-YYYY regardless of locale', () {
      expect(ddMmYyyy(DateTime(1998, 5, 3)), '03-05-1998');
    });
    test('pads single-digit day and month', () {
      expect(ddMmYyyy(DateTime(2000, 1, 9)), '09-01-2000');
    });
  });

  group('earnRangeLabel', () {
    test('shows a range when matches pay differently', () {
      expect(earnRangeLabel(l10n, '80', '1200'), 'Earn ฿80–1,200');
    });
    test('collapses to a single amount when every match pays the same', () {
      expect(earnRangeLabel(l10n, '520', '520'), 'Earn ฿520');
    });
  });

  group('initials', () {
    test('first + last', () => expect(initials('Ada Lovelace'), 'AL'));
    test('single name', () => expect(initials('Hiww'), 'H'));
    test('empty', () => expect(initials('   '), '?'));
  });

  test('pluralize', () {
    expect(pluralize(1, 'traveler'), '1 traveler');
    expect(pluralize(3, 'traveler'), '3 travelers');
    expect(pluralize(2, 'want'), '2 wants');
  });

  group('countdown', () {
    final now = DateTime(2026, 11, 12, 10, 0);
    test('shows hours and minutes when over an hour remains', () {
      expect(countdown(l10n, now.add(const Duration(hours: 1, minutes: 5)), now: now), '1h 5m left');
    });
    test('shows minutes only under an hour', () {
      expect(countdown(l10n, now.add(const Duration(minutes: 42)), now: now), '42m left');
    });
    test('shows a friendly message under a minute', () {
      expect(countdown(l10n, now.add(const Duration(seconds: 30)), now: now), 'Less than a minute left');
    });
    test('reports Expired once the deadline has passed', () {
      expect(countdown(l10n, now.subtract(const Duration(minutes: 1)), now: now), 'Expired');
    });
    test('empty for a null deadline', () {
      expect(countdown(l10n, null, now: now), '');
    });
  });
}
