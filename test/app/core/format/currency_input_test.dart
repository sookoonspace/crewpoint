import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/format/currency_input.dart';

void main() {
  group('parseCurrencyInput (locale-aware pure parser)', () {
    test('en_US parses positive + zero + 2-decimal values', () {
      expect(parseCurrencyInput('0', locale: 'en_US'), 0.0);
      expect(parseCurrencyInput('12', locale: 'en_US'), 12.0);
      expect(parseCurrencyInput('1234.56', locale: 'en_US'), 1234.56);
    });

    test('empty / whitespace returns null', () {
      expect(parseCurrencyInput('', locale: 'en_US'), isNull);
      expect(parseCurrencyInput('   ', locale: 'en_US'), isNull);
    });

    test('en_US rejects negative + non-numeric + 3-decimal', () {
      expect(
        () => parseCurrencyInput('-1', locale: 'en_US'),
        throwsFormatException,
      );
      expect(
        () => parseCurrencyInput('abc', locale: 'en_US'),
        throwsFormatException,
      );
      expect(
        () => parseCurrencyInput('1.234', locale: 'en_US'),
        throwsFormatException,
      );
    });

    test('de_DE accepts comma decimal; rejects 3-decimal comma', () {
      expect(parseCurrencyInput('0,5', locale: 'de_DE'), 0.5);
      expect(parseCurrencyInput('1234,56', locale: 'de_DE'), 1234.56);
      expect(
        () => parseCurrencyInput('1,234', locale: 'de_DE'),
        throwsFormatException,
      );
    });
  });
}
