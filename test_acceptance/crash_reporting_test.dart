// O-02, crash reporting part (#92, Req 68). Backend error alerts are the
// other part, in #93, so O-02 is not finished until both are.
import 'dart:convert';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/crash_reporter.dart';
import 'package:crewpoint_app/app/core/services/sentry_crash_reporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('O-02 a crash report leaves the device with no personal data', () async {
    final options = SentryFlutterOptions();
    configureSentry(
      options,
      dsn: 'https://key@o1.ingest.sentry.io/1',
      environment: 'prod',
      reportDebugBuilds: true,
    );
    final event = SentryEvent(
      user: SentryUser(
        id: 'Xy9kQ2mN8pR4sT6vW1zA0bC3dE5f',
        email: 'asha.patel@example.com',
        ipAddress: '203.0.113.7',
      ),
      message: SentryMessage('Could not invite asha.patel@example.com'),
      exceptions: [
        SentryException(
          type: 'FirebaseException',
          value:
              'PERMISSION_DENIED: users/Xy9kQ2mN8pR4sT6vW1zA0bC3dE5f, '
              'phone +44 7700 900123',
        ),
      ],
      breadcrumbs: [
        Breadcrumb(message: 'Opened chat', data: {'text': 'Hi Asha'}),
      ],
      tags: {'route': '/dashboard/event/aB3dE5fG7hJ9kL1mN2pQ/people/p1Xy?q=a'},
      contexts: Contexts(device: SentryDevice(name: "Asha's iPhone")),
      serverName: 'Ashas-iPhone',
    );

    final sent = await options.beforeSend!(event, Hint());
    final json = jsonEncode(sent!.toJson());

    for (final personal in [
      'Asha',
      'asha',
      'example.com',
      '203.0.113.7',
      'Xy9kQ2mN8pR4sT6vW1zA0bC3dE5f',
      '7700',
      'aB3dE5fG7hJ9kL1mN2pQ',
    ]) {
      expect(json, isNot(contains(personal)), reason: personal);
    }
    expect(sent.tags!['route'], '/dashboard/event/:id/people/:id');
    expect(sent.exceptions!.single.type, 'FirebaseException');
  });

  test('O-02 the app sends nothing unless main starts a reporter', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final reporter = container.read(crashReporterProvider);

    expect(reporter, isA<NoCrashReporter>());
    expect(reporter.isOn, isFalse);
  });
}
