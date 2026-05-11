import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/budget_estimate_field.dart';

void main() {
  // Locale-aware parser matching NumberFormat.simpleCurrency render.
  // Empty/whitespace input → null (valid, persists as no estimate).
  // Invalid input → FormatException (UI maps to validator error string).

  group('parseBudgetEstimate — en_US', () {
    test('parses valid inputs', () {
      expect(parseBudgetEstimate('0', locale: 'en_US'), 0.0);
      expect(parseBudgetEstimate('0.5', locale: 'en_US'), 0.5);
      expect(parseBudgetEstimate('12', locale: 'en_US'), 12.0);
      expect(parseBudgetEstimate('1234.56', locale: 'en_US'), 1234.56);
    });

    test('empty string returns null (valid)', () {
      expect(parseBudgetEstimate('', locale: 'en_US'), isNull);
      expect(parseBudgetEstimate('   ', locale: 'en_US'), isNull);
    });

    test('rejects negative, non-numeric, and too many decimals', () {
      expect(
        () => parseBudgetEstimate('-1', locale: 'en_US'),
        throwsFormatException,
      );
      expect(
        () => parseBudgetEstimate('abc', locale: 'en_US'),
        throwsFormatException,
      );
      expect(
        () => parseBudgetEstimate('1.234', locale: 'en_US'),
        throwsFormatException,
      );
    });
  });

  group('parseBudgetEstimate — de_DE', () {
    test('parses comma-decimal inputs', () {
      expect(parseBudgetEstimate('0,5', locale: 'de_DE'), 0.5);
      expect(parseBudgetEstimate('1234,56', locale: 'de_DE'), 1234.56);
    });

    test('rejects 3-decimal comma input', () {
      expect(
        () => parseBudgetEstimate('1,234', locale: 'de_DE'),
        throwsFormatException,
      );
    });
  });
}
