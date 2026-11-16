import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('Sentry.getClient')
external JSObject? _sentryClient();

/// On web, Sentry also starts its JavaScript SDK, which reports uncaught
/// browser errors itself and so skips `scrubEvent` (Req 68). This drops
/// every report the JavaScript SDK makes on its own. The app's reports are
/// unaffected: they reach it already packaged (`sendEnvelope`), which does
/// not run `beforeSend`. Uncaught Dart errors are caught by the zone in
/// `runWithCrashReporting` and scrubbed instead.
void dropUnscrubbedWebReports() {
  final client = _sentryClient();
  final options = client?.callMethod<JSObject?>('getOptions'.toJS);
  if (options == null) return;
  options['beforeSend'] = ((JSAny? event, JSAny? hint) => null).toJS;
}
