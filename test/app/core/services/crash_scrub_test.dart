import 'package:crewpoint_app/app/core/services/crash_scrub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('routeForReport', () {
    test('replaces IDs and codes with :id and drops the query', () {
      expect(
        routeForReport(
          '/dashboard/event/aB3dE5fG7hJ9kL1mN2pQ/people/x7Yz9AbCdEf?group=g1',
        ),
        '/dashboard/event/:id/people/:id',
      );
      expect(routeForReport('/join/ABC234?from=x'), '/join/:id');
      expect(
        routeForReport('/dashboard/event/abc123/tasks/new'),
        '/dashboard/event/:id/tasks/new',
      );
    });

    test('keeps fixed route names', () {
      expect(
        routeForReport('/dashboard/event/:id/settings/expenses'),
        '/dashboard/event/:id/settings/expenses',
      );
      expect(routeForReport('/profile/dev-tools'), '/profile/dev-tools');
      expect(routeForReport('/'), '/');
    });
  });

  group('maskPersonalText', () {
    test('masks email addresses', () {
      expect(
        maskPersonalText('No account for asha.patel+trip@example.co.uk here'),
        'No account for <email> here',
      );
    });

    test('masks phone numbers in common formats', () {
      expect(
        maskPersonalText(
          'Call +1 (415) 555-0134, 07700 900123 or +91-98765-43210 now',
        ),
        'Call <phone>, <phone> or <phone> now',
      );
    });

    test('replaces user and document IDs, keeping long words', () {
      expect(
        maskPersonalText(
          'PERMISSION_DENIED on users/Xy9kQ2mN8pR4sT6vW1zA0bC3dE5f/private '
          'in PlatformDispatcherOnError',
        ),
        'PERMISSION_DENIED on users/<id>/private in PlatformDispatcherOnError',
      );
    });

    test('keeps short numbers, times, dates and versions', () {
      const text =
          'Line 42 failed at 14:22 on 2026-11-12 in 1.4.0+17, code 503, '
          'index 12345';
      expect(maskPersonalText(text), text);
    });
  });
}
