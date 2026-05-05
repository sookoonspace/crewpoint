import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/auth/domain/display_name_helper.dart';

void main() {
  group('deriveDisplayNameFromEmail', () {
    test('title-cases a dot-separated local-part', () {
      expect(deriveDisplayNameFromEmail('jane.doe@x.com'), equals('Jane Doe'));
    });

    test('preserves all-numeric tokens unchanged', () {
      expect(deriveDisplayNameFromEmail('12345@x.com'), equals('12345'));
    });

    test('strips plus-tag suffix from local-part', () {
      expect(deriveDisplayNameFromEmail('jane+work@x.com'), equals('Jane'));
    });

    test('handles single-character local-part', () {
      expect(deriveDisplayNameFromEmail('a@x.com'), equals('A'));
    });

    test('splits on underscore and lowercases tail', () {
      expect(
        deriveDisplayNameFromEmail('JOHN_smith@x.com'),
        equals('John Smith'),
      );
    });

    test('falls back to "CrewPoint user" for null/empty/no-local-part', () {
      const fallback = 'CrewPoint user';
      expect(deriveDisplayNameFromEmail(null), equals(fallback));
      expect(deriveDisplayNameFromEmail(''), equals(fallback));
      expect(deriveDisplayNameFromEmail('@x.com'), equals(fallback));
      expect(deriveDisplayNameFromEmail('+work@x.com'), equals(fallback));
    });
  });
}
