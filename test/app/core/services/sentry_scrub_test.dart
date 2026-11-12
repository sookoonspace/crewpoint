// Sentry still sends `extra`, so the test checks it is cleared.
// ignore_for_file: deprecated_member_use
import 'package:crewpoint_app/app/core/services/sentry_crash_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('a report carries no user, request, server name or extra data', () {
    final event = SentryEvent(
      user: SentryUser(
        id: 'uid123',
        email: 'asha@example.com',
        ipAddress: '10.0.0.1',
      ),
      request: SentryRequest(url: 'https://x.test/?email=asha@example.com'),
      serverName: 'Ashas-MacBook',
      extra: {'name': 'Asha Patel'},
    );

    final scrubbed = scrubEvent(event);

    expect(scrubbed.user, isNull);
    expect(scrubbed.request, isNull);
    expect(scrubbed.serverName, isNull);
    expect(scrubbed.extra, isNull);
  });

  test('error text and breadcrumbs are masked, keeping error types', () {
    final event = SentryEvent(
      message: SentryMessage('Invite for asha@example.com failed'),
      exceptions: [
        SentryException(
          type: 'FirebaseException',
          value: 'No document users/Xy9kQ2mN8pR4sT6vW1zA0bC3dE5f',
        ),
      ],
      breadcrumbs: [
        Breadcrumb(
          message: 'Calling +1 (415) 555-0134',
          category: 'console',
          data: {'body': 'Asha Patel'},
        ),
      ],
    );

    final scrubbed = scrubEvent(event);

    expect(scrubbed.message!.formatted, 'Invite for <email> failed');
    expect(scrubbed.exceptions!.single.type, 'FirebaseException');
    expect(scrubbed.exceptions!.single.value, 'No document users/<id>');
    final crumb = scrubbed.breadcrumbs!.single;
    expect(crumb.message, 'Calling <phone>');
    expect(crumb.category, 'console');
    expect(crumb.data, isNull);
  });

  test('device names go and routes lose their IDs', () {
    final event = SentryEvent(
      transaction: '/dashboard/event/aB3dE5fG7hJ9kL1mN2pQ',
      tags: {'route': '/join/ABC234?from=x', 'flavor': 'dev'},
      contexts: Contexts(
        device: SentryDevice(name: "Asha's iPhone", model: 'iPhone15,2'),
      ),
    );

    final scrubbed = scrubEvent(event);

    expect(scrubbed.contexts.device!.name, isNull);
    expect(scrubbed.contexts.device!.model, 'iPhone15,2');
    expect(scrubbed.transaction, '/dashboard/event/:id');
    expect(scrubbed.tags, {'route': '/join/:id', 'flavor': 'dev'});
  });
}
