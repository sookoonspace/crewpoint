import 'package:crewpoint_app/app/core/version/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isBelowMinimum', () {
    test('a lower version is below the minimum', () {
      expect(isBelowMinimum(current: '1.2.3', minimum: '1.3.0'), isTrue);
    });

    test('the minimum itself, or higher, is not below', () {
      expect(isBelowMinimum(current: '1.3.0', minimum: '1.3.0'), isFalse);
      expect(isBelowMinimum(current: '2.0.0', minimum: '1.9.9'), isFalse);
    });

    test('compares parts as numbers, not text', () {
      expect(isBelowMinimum(current: '1.9.0', minimum: '1.10.0'), isTrue);
    });

    test('ignores a build number and fills missing parts with zero', () {
      expect(isBelowMinimum(current: '1.4.0+7', minimum: '1.4'), isFalse);
      expect(isBelowMinimum(current: '1.3', minimum: '1.3.1'), isTrue);
    });

    test('a version that cannot be read never blocks the app', () {
      expect(isBelowMinimum(current: '1.0.0', minimum: 'soon'), isFalse);
      expect(isBelowMinimum(current: '1.0.0', minimum: ''), isFalse);
      expect(isBelowMinimum(current: 'unknown', minimum: '9.0.0'), isFalse);
    });
  });
}
