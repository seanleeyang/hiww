import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/core/thai_id_formatter.dart';

void main() {
  group('formatThaiNationalId', () {
    test('groups 13 digits as 1-4-5-2-1', () {
      expect(formatThaiNationalId('1234567890123'), '1-2345-67890-12-3');
    });

    test('formats a partial number as typed so far', () {
      expect(formatThaiNationalId('123'), '1-23');
      expect(formatThaiNationalId('1'), '1');
    });

    test('strips non-digit characters, including pre-existing hyphens', () {
      expect(formatThaiNationalId('1-2345-67890-12-3'), '1-2345-67890-12-3');
      expect(formatThaiNationalId('abc123def456ghi7890123'), '1-2345-67890-12-3');
    });

    test('caps at 13 digits, ignoring anything typed beyond that', () {
      expect(formatThaiNationalId('12345678901239999'), '1-2345-67890-12-3');
    });

    test('empty input formats to an empty string', () {
      expect(formatThaiNationalId(''), '');
    });
  });
}
