import 'dart:async';

import 'package:crewpoint_app/app/core/services/crash_reporter.dart';
import 'package:crewpoint_app/app/core/services/crash_scrub.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

/// Reports through Sentry on iOS, Android and web (Req 68). Start it with
/// [SentryCrashReporter.start] from `main` only.
class SentryCrashReporter implements ICrashReporter {
  SentryCrashReporter._();

  /// Starts Sentry when [dsn] is set, catching uncaught Flutter, platform
  /// and native errors from then on. With no DSN nothing is sent.
  /// Debug builds report only with [reportDebugBuilds], so everyday
  /// development does not fill the dashboard.
  static Future<ICrashReporter> start({
    required String dsn,
    required String environment,
    bool reportDebugBuilds = false,
  }) async {
    if (dsn.isEmpty) return const NoCrashReporter();
    await SentryFlutter.init(
      (options) => configureSentry(
        options,
        dsn: dsn,
        environment: environment,
        reportDebugBuilds: reportDebugBuilds,
      ),
    );
    return SentryCrashReporter._();
  }

  @override
  bool get isOn => true;

  @override
  Future<String?> report(Object error, StackTrace stackTrace) async {
    final id = await Sentry.captureException(error, stackTrace: stackTrace);
    return id == const SentryId.empty() ? null : id.toString();
  }

  @override
  void setRoute(String location) {
    unawaited(
      Future.sync(
        () => Sentry.configureScope(
          (scope) => scope.setTag('route', routeForReport(location)),
        ),
      ),
    );
  }
}

/// The options CrewPoint starts Sentry with: no personal data, no screen
/// content, and every event and breadcrumb scrubbed.
void configureSentry(
  SentryFlutterOptions options, {
  required String dsn,
  required String environment,
  required bool reportDebugBuilds,
}) {
  options
    ..dsn = dsn
    ..environment = environment
    ..sendDefaultPii = false
    ..attachScreenshot = false
    // The view hierarchy would carry on-screen text such as names.
    // ignore: experimental_member_use
    ..attachViewHierarchy = false
    // debugPrint output can hold names.
    ..enablePrintBreadcrumbs = false
    ..considerInAppFramesByDefault = false
    ..addInAppInclude('crewpoint_app')
    ..beforeBreadcrumb = ((crumb, _) =>
        crumb == null ? null : scrubBreadcrumb(crumb))
    ..beforeSend = ((event, _) =>
        kReleaseMode || reportDebugBuilds ? scrubEvent(event) : null);
  // Workaround for https://github.com/getsentry/sentry-dart/issues/3247.
  options.tracePropagationTargets.clear();
}

/// Removes everything from [event] that could identify a person (Req 68):
/// no user, request, server or device name and no extra data, with error
/// text and breadcrumbs masked by [maskPersonalText] and routes reduced by
/// [routeForReport]. Runs as `beforeSend`, after Sentry's own processors
/// have added context.
SentryEvent scrubEvent(SentryEvent event) {
  event
    ..user = null
    ..request = null
    ..serverName = null
    // Deprecated in Sentry, but still sent when set.
    // ignore: deprecated_member_use
    ..extra = null
    ..transaction = _route(event.transaction)
    ..tags = event.tags?.map(
      (key, value) =>
          MapEntry(key, key == 'route' ? routeForReport(value) : value),
    );
  final message = event.message;
  if (message != null) {
    message
      ..formatted = maskPersonalText(message.formatted)
      ..template = _mask(message.template)
      ..params = null;
  }
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    exception.value = _mask(exception.value);
  }
  for (final crumb in event.breadcrumbs ?? const <Breadcrumb>[]) {
    scrubBreadcrumb(crumb);
  }
  event.contexts.device?.name = null;
  return event;
}

/// Masks a breadcrumb's message and drops its data, which can hold text
/// from the screen or a request.
Breadcrumb scrubBreadcrumb(Breadcrumb crumb) => crumb
  ..message = _mask(crumb.message)
  ..data = null;

String? _mask(String? text) => text == null ? null : maskPersonalText(text);

String? _route(String? route) => route == null ? null : routeForReport(route);
