/// Single source of truth for "event date range" display strings.
///
/// Two surfaces consume this:
/// - Home dashboard tile (`lib/app/core/widgets/event_tile.dart`).
/// - Per-event hero (`event_dashboard_screen.dart` → `_EventHero`).
///
/// Lives under `core/format/` (not `features/dashboard/domain/`) so the
/// `core/widgets/` consumer can import it without violating the layered
/// dependency direction.
library;

import 'package:intl/intl.dart';

/// Returns the canonical event-date-range display string.
///
/// Shape: `'MMM d – MMM d'` (en-dash, no year, no comma) when both
/// endpoints share `now.year`; appends `', yyyy'` to each endpoint
/// when the range spans years or either endpoint is in a different
/// year than `now`. Same-day ranges collapse to a single date.
///
/// `now` is injectable for tests; production passes `DateTime.now()`.
String formatEventDateRange(DateTime? start, DateTime? end, {DateTime? now}) {
  if (start == null) return '';
  final nowYear = (now ?? DateTime.now()).year;
  final needsYear =
      start.year != nowYear || (end != null && end.year != nowYear);
  final fmt = needsYear ? DateFormat.yMMMd() : DateFormat.MMMd();
  if (end == null || end == start) return fmt.format(start);
  return '${fmt.format(start)} – ${fmt.format(end)}';
}
