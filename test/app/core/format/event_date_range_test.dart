import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/format/event_date_range.dart';

void main() {
  group('formatEventDateRange', () {
    test(
      'same-year both set → "MMM d – MMM d" (en-dash, no year, no comma)',
      () {
        final result = formatEventDateRange(
          DateTime(2026, 5, 22),
          DateTime(2026, 9, 30),
          now: DateTime(2026, 6, 11),
        );
        expect(result, 'May 22 – Sep 30');
      },
    );

    test('cross-year range → year appended to both endpoints', () {
      final result = formatEventDateRange(
        DateTime(2026, 12, 22),
        DateTime(2027, 1, 5),
        now: DateTime(2026, 12, 11),
      );
      expect(result, 'Dec 22, 2026 – Jan 5, 2027');
    });

    test('same-day range collapses to a single date', () {
      final result = formatEventDateRange(
        DateTime(2026, 5, 22),
        DateTime(2026, 5, 22),
        now: DateTime(2026, 6, 11),
      );
      expect(result, 'May 22');
    });

    test('null end → single start endpoint, no separator', () {
      final result = formatEventDateRange(
        DateTime(2026, 5, 22),
        null,
        now: DateTime(2026, 6, 11),
      );
      expect(result, 'May 22');
    });

    test('null both → empty string', () {
      expect(formatEventDateRange(null, null, now: DateTime(2026, 6, 11)), '');
    });

    test('prior-year (now.year != range.year) → year appended', () {
      final result = formatEventDateRange(
        DateTime(2025, 5, 22),
        DateTime(2025, 9, 30),
        now: DateTime(2026, 6, 11),
      );
      expect(result, 'May 22, 2025 – Sep 30, 2025');
    });
  });
}
