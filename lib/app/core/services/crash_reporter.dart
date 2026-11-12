/// Crash reporting seam (Req 68). The app reports through this, so tests
/// never reach a real reporter: they get [NoCrashReporter] from
/// `crashReporterProvider`, and only `main` starts Sentry.
abstract interface class ICrashReporter {
  /// Whether reports are sent anywhere.
  bool get isOn;

  /// Sends [error] and returns the report's ID, or null when off.
  Future<String?> report(Object error, StackTrace stackTrace);

  /// Records the screen the person is on, without IDs, for later reports.
  void setRoute(String location);
}

/// Sends nothing. Used in tests and when no DSN is configured.
class NoCrashReporter implements ICrashReporter {
  const NoCrashReporter();

  @override
  bool get isOn => false;

  @override
  Future<String?> report(Object error, StackTrace stackTrace) async => null;

  @override
  void setRoute(String location) {}
}
