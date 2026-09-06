import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/core/format.dart';

void main() {
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
        dateRange(DateTime(2026, 11, 12), DateTime(2026, 11, 19)),
        '12 Nov 2026 to 19 Nov 2026',
      );
    });
    test('cross month shows both full dates', () {
      expect(
        dateRange(DateTime(2026, 11, 28), DateTime(2026, 12, 3)),
        '28 Nov 2026 to 3 Dec 2026',
      );
    });
    test('single date', () {
      expect(dateRange(DateTime(2026, 11, 12), null), '12 Nov 2026');
      expect(dateRange(null, null), '');
    });
  });

  group('earnRangeLabel', () {
    test('shows a range when matches pay differently', () {
      expect(earnRangeLabel('80', '1200'), 'Earn ฿80–1,200');
    });
    test('collapses to a single amount when every match pays the same', () {
      expect(earnRangeLabel('520', '520'), 'Earn ฿520');
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
}
