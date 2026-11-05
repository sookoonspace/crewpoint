/// Time zone logic for events (Req 23). Pure Dart, so it runs in unit tests and
/// in PDF builders without Flutter.
library;

import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Loads the zone data, which is bundled in the code on every platform,
/// including web. Call once at startup.
void initEventTimeZones() => tz_data.initializeTimeZones();

/// Every zone an organizer can choose, in alphabetical order.
List<String> get allTimeZones =>
    tz.timeZoneDatabase.locations.keys.toList()..sort();

bool isKnownTimeZone(String zone) =>
    tz.timeZoneDatabase.locations.containsKey(zone);

tz.Location _location(String zone) =>
    isKnownTimeZone(zone) ? tz.getLocation(zone) : tz.UTC;

/// [instant] as the clock reads in [zone]. An unknown zone reads as UTC.
DateTime inEventZone(DateTime instant, String zone) =>
    tz.TZDateTime.from(instant, _location(zone));

/// The UTC instant for a wall-clock time in [zone], which stays correct across
/// daylight-saving changes.
DateTime eventLocalToUtc(
  int year,
  int month,
  int day,
  String zone, {
  int hour = 0,
  int minute = 0,
}) => tz.TZDateTime(_location(zone), year, month, day, hour, minute).toUtc();

/// How a date-only value is stored: midnight UTC on the chosen calendar date,
/// which then reads as that date in every zone.
DateTime storedCalendarDate(DateTime picked) =>
    DateTime.utc(picked.year, picked.month, picked.day);

/// The zone to show beside a date, or null when the viewer's device reads the
/// same time. Different names for the same time count as the same.
String? zoneNoteFor(
  String eventZone,
  String? deviceZone, {
  required DateTime at,
}) {
  if (deviceZone == null) return null;
  final there = tz.TZDateTime.from(at, _location(eventZone));
  final here = tz.TZDateTime.from(at, _location(deviceZone));
  return there.timeZoneOffset == here.timeZoneOffset ? null : eventZone;
}
