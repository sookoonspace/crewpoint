/// Centralized duration tokens for CrewPoint.
///
/// Production-only. Test-only durations (e.g. the 50 ms bounded-pump frame)
/// live alongside their test helpers, not here. Adding `pumpFrame` here was
/// considered and rejected — test infrastructure shouldn't ship in the app
/// bundle and shouldn't bloat the production API surface.
abstract final class AppDurations {
  /// Quick interactions (chip toggle, ripple, tooltip dismiss).
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions (snackbar slide, modal sheet open).
  static const Duration medium = Duration(milliseconds: 250);

  /// Slower, more deliberate transitions (page route, hero animation).
  static const Duration slow = Duration(milliseconds: 350);

  /// Snackbar display time before auto-dismiss.
  static const Duration snackbar = Duration(seconds: 4);
}
