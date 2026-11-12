import 'package:crewpoint_app/app/core/services/sentry_crash_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

SentryFlutterOptions _configured({bool reportDebugBuilds = false}) {
  final options = SentryFlutterOptions();
  configureSentry(
    options,
    dsn: 'https://key@o1.ingest.sentry.io/1',
    environment: 'dev',
    reportDebugBuilds: reportDebugBuilds,
  );
  return options;
}

SentryEvent _event() => SentryEvent(
  user: SentryUser(id: 'uid123'),
  message: SentryMessage('Invite for asha@example.com failed'),
);

void main() {
  test('sends nothing personal and attaches no screen content', () {
    final options = _configured();

    expect(options.dsn, 'https://key@o1.ingest.sentry.io/1');
    expect(options.environment, 'dev');
    expect(options.sendDefaultPii, isFalse);
    expect(options.attachScreenshot, isFalse);
    // ignore: experimental_member_use
    expect(options.attachViewHierarchy, isFalse);
    expect(options.enablePrintBreadcrumbs, isFalse);
  });

  test('every breadcrumb is scrubbed before it is kept', () {
    final crumb = _configured().beforeBreadcrumb!(
      Breadcrumb(message: 'Mail asha@example.com', data: {'k': 'v'}),
      Hint(),
    );

    expect(crumb!.message, 'Mail <email>');
    expect(crumb.data, isNull);
  });

  test('debug builds report only when asked to, and always scrubbed', () async {
    // Tests run as a debug build.
    expect(await _configured().beforeSend!(_event(), Hint()), isNull);

    final sent = await _configured(reportDebugBuilds: true).beforeSend!(
      _event(),
      Hint(),
    );
    expect(sent!.user, isNull);
    expect(sent.message!.formatted, 'Invite for <email> failed');
  });
}
