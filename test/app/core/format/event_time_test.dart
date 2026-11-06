import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('times in a zone (Req 23)', () {
    test('an instant shows in the event zone', () {
      final instant = DateTime.utc(2027, 7, 17, 23, 30);
      final there = inEventZone(instant, 'America/Chicago');
      expect(DateFormat('yyyy-MM-dd HH:mm').format(there), '2027-07-17 18:30');
      final tokyo = inEventZone(instant, 'Asia/Tokyo');
      expect(DateFormat('yyyy-MM-dd HH:mm').format(tokyo), '2027-07-18 08:30');
    });

    test('local time converts to UTC for storage', () {
      expect(
        eventLocalToUtc(2027, 7, 17, 'America/Chicago', hour: 18, minute: 30),
        DateTime.utc(2027, 7, 17, 23, 30),
      );
    });

    test('the same local time stays correct across daylight saving', () {
      // Chicago moved its clocks on 14 March 2027.
      final before = eventLocalToUtc(2027, 3, 13, 'America/Chicago', hour: 9);
      final after = eventLocalToUtc(2027, 3, 15, 'America/Chicago', hour: 9);
      expect(before, DateTime.utc(2027, 3, 13, 15));
      expect(after, DateTime.utc(2027, 3, 15, 14));
      expect(inEventZone(before, 'America/Chicago').hour, 9);
      expect(inEventZone(after, 'America/Chicago').hour, 9);
    });

    test('an unknown zone falls back to UTC rather than failing', () {
      final instant = DateTime.utc(2027, 7, 17, 23, 30);
      expect(inEventZone(instant, 'Mars/Base').hour, 23);
      expect(isKnownTimeZone('Mars/Base'), isFalse);
      expect(isKnownTimeZone('America/Chicago'), isTrue);
    });

    test('the zone list holds real zones', () {
      expect(allTimeZones, containsAll(['America/Chicago', 'Asia/Kolkata']));
    });
  });

  group('showing the zone where a device differs', () {
    final at = DateTime.utc(2027, 7, 17);

    test('shows it when the offsets differ', () {
      expect(
        zoneNoteFor('America/Chicago', 'Asia/Tokyo', at: at),
        'America/Chicago',
      );
    });

    test('hides it for the same zone, or another name for the same time', () {
      expect(zoneNoteFor('Asia/Kolkata', 'Asia/Kolkata', at: at), isNull);
      expect(zoneNoteFor('Asia/Kolkata', 'Asia/Calcutta', at: at), isNull);
    });

    test('hides it when the device zone is unknown', () {
      expect(zoneNoteFor('Asia/Kolkata', null, at: at), isNull);
    });
  });

  group('date-only events', () {
    const zones = ['Pacific/Honolulu', 'America/Chicago', 'UTC', 'Asia/Tokyo'];
    EventModel event(String zone) => EventModel(
      id: 'e',
      title: 'T',
      creatorId: 'u',
      timeZone: zone,
      dateOnly: true,
      startDate: storedCalendarDate(DateTime(2027, 7, 17)),
      endDate: storedCalendarDate(DateTime(2027, 7, 20)),
    );

    test('stay on the chosen date in every event zone', () {
      for (final zone in zones) {
        expect(event(zone).displayStart, DateTime(2027, 7, 17), reason: zone);
        expect(event(zone).displayEnd, DateTime(2027, 7, 20), reason: zone);
      }
    });

    test('are past only after their last day in the event zone', () {
      final tokyo = event('Asia/Tokyo');
      final chicago = event('America/Chicago');
      // 21 July 00:30 in Tokyo is still 20 July in Chicago.
      final now = DateTime.utc(2027, 7, 20, 15, 30);
      expect(tokyo.isPast(now), isTrue);
      expect(chicago.isPast(now), isFalse);
    });
  });

  group('an event from before date-only events', () {
    test('keeps showing on the device, as it always has', () {
      final instant = DateTime(2027, 7, 17);
      final old = EventModel(
        id: 'e',
        title: 'T',
        creatorId: 'u',
        startDate: instant,
      );
      expect(old.displayStart, instant);
    });
  });

  group('calendar days for tasks', () {
    const event = EventModel(
      id: 'e',
      title: 'T',
      creatorId: 'u',
      timeZone: 'Asia/Tokyo',
    );

    test('a chosen day round-trips through the event zone', () {
      final stored = event.startOfDay(DateTime(2027, 7, 17));
      expect(stored, DateTime.utc(2027, 7, 16, 15));
      expect(event.calendarDay(stored), DateTime(2027, 7, 17));
    });

    // Older due dates are midnight on the creator's device. The migration
    // gives the event the creator's zone, so they read as the chosen day.
    test(
      'an older due date reads correctly once the event has the creator zone',
      () {
        for (final (zone, instant) in [
          ('America/New_York', DateTime.utc(2026, 3, 10, 4)),
          ('Asia/Kolkata', DateTime.utc(2026, 3, 9, 18, 30)),
          ('Pacific/Auckland', DateTime.utc(2026, 3, 9, 11)),
        ]) {
          final migrated = EventModel(
            id: 'e',
            title: 'T',
            creatorId: 'u',
            timeZone: zone,
          );
          expect(
            migrated.calendarDay(instant),
            DateTime(2026, 3, 10),
            reason: zone,
          );
          expect(
            DateFormat('yyyy-MM-dd').format(migrated.inZone(instant)),
            '2026-03-10',
            reason: zone,
          );
        }
      },
    );
  });
}
