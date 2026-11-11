import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 48, 49: sessions, how the schedule groups them by day and venue, and
/// how a venue is reached.
void main() {
  const event = EventModel(
    id: 'e1',
    title: 'Convention',
    creatorId: 'owner',
    timeZone: 'America/Chicago',
    venues: [
      EventVenue(id: 'hall', name: 'Garland Hall', address: '1 Main St'),
      EventVenue(id: 'park', name: 'Picnic park'),
      EventVenue(id: 'parking', name: 'Parking'),
    ],
  );

  SessionModel session(
    String id,
    String startUtc, {
    String? venueId,
    bool locationTba = false,
    String? type,
  }) => SessionModel(
    id: id,
    title: id,
    startAt: DateTime.parse(startUtc),
    venueId: venueId,
    locationTba: locationTba,
    type: type,
  );

  group('SessionModel', () {
    test('round-trips through Firestore', () {
      final original = SessionModel(
        id: 's1',
        title: 'Lunch',
        startAt: DateTime.utc(2027, 7, 17, 17, 30),
        endAt: DateTime.utc(2027, 7, 17, 19),
        timeTbc: true,
        venueId: 'park',
        locationTba: false,
        type: 'Lunch',
        tags: const ['outdoor'],
        capacity: 400,
        eligibility: const SessionEligibility(
          categoryIds: ['child'],
          filterTags: ['program=Kids'],
        ),
        hidden: true,
      );
      final data = original.toFirestore(updatedBy: 'owner');
      expect(data['updatedBy'], 'owner');
      expect(data['updatedAt'], isA<FieldValue>());
      expect(data['startAt'], isA<Timestamp>());
      data['updatedAt'] = Timestamp.fromDate(DateTime.utc(2027));
      expect(SessionModel.fromFirestore('s1', data), original);
    });

    test('an empty optional value is stored as null', () {
      final data = SessionModel(
        id: 's',
        title: 'Party',
        startAt: DateTime.utc(2027),
        type: '  ',
      ).toFirestore(updatedBy: 'u');
      expect(data['endAt'], isNull);
      expect(data['venueId'], isNull);
      expect(data['type'], isNull);
      expect(data['capacity'], isNull);
      expect(data['hidden'], isFalse);
      expect(data['eligibility'], {
        'categoryIds': <String>[],
        'filterTags': <String>[],
      });
    });

    test('reads a damaged document without throwing', () {
      final s = SessionModel.fromFirestore('x', const {
        'title': 7,
        'tags': 'a',
      });
      expect(s.title, '');
      expect(s.tags, isEmpty);
      expect(s.startAt, DateTime.utc(1970));
    });
  });

  group('SessionEligibility', () {
    const kids = SessionEligibility(categoryIds: ['child']);
    const ladies = SessionEligibility(filterTags: ['program=Ladies']);
    const both = SessionEligibility(
      categoryIds: ['adult'],
      filterTags: ['program=Ladies', 'program=All'],
    );

    test('empty admits everyone', () {
      expect(const SessionEligibility().isEveryone, isTrue);
      expect(const SessionEligibility().admits(), isTrue);
    });

    test('admits by age band', () {
      expect(kids.admits(categoryId: 'child'), isTrue);
      expect(kids.admits(categoryId: 'adult'), isFalse);
      expect(kids.admits(), isFalse);
    });

    test('admits by any of the field answers', () {
      expect(ladies.admits(tags: const ['program=Ladies']), isTrue);
      expect(ladies.admits(tags: const ['program=Men']), isFalse);
    });

    test('needs both an age band and an answer when it names both', () {
      expect(both.admits(categoryId: 'adult', tags: ['program=All']), isTrue);
      expect(both.admits(categoryId: 'child', tags: ['program=All']), isFalse);
      expect(both.admits(categoryId: 'adult'), isFalse);
    });
  });

  group('byDay', () {
    test('groups by the calendar day where the event is, in time order', () {
      final days = byDay(event, [
        // 19:00 on 17 July in Chicago is 00:00 UTC on the 18th.
        session('dinner', '2027-07-18T00:00:00Z'),
        session('breakfast', '2027-07-17T13:00:00Z'),
        session('farewell', '2027-07-19T13:00:00Z'),
        session('lunch', '2027-07-17T17:30:00Z'),
      ]);
      expect(
        [for (final d in days) d.day],
        [DateTime(2027, 7, 17), DateTime(2027, 7, 19)],
      );
      expect(
        [for (final s in days.first.sessions) s.id],
        ['breakfast', 'lunch', 'dinner'],
      );
    });

    test('is empty with no sessions', () {
      expect(byDay(event, const []), isEmpty);
    });
  });

  group('byVenue', () {
    test('lists every venue in order, then sessions without one', () {
      final groups = byVenue(event, [
        session('lunch', '2027-07-17T17:30:00Z', venueId: 'park'),
        session('dinner', '2027-07-18T00:00:00Z', venueId: 'hall'),
        session('breakfast', '2027-07-17T13:00:00Z', venueId: 'hall'),
        session('farewell', '2027-07-19T13:00:00Z', locationTba: true),
        session('gone', '2027-07-19T15:00:00Z', venueId: 'removed'),
      ]);
      expect(
        [for (final g in groups) g.venue?.id],
        ['hall', 'park', 'parking', null],
      );
      expect(
        [for (final s in groups.first.sessions) s.id],
        ['breakfast', 'dinner'],
      );
      expect(groups[2].sessions, isEmpty);
      expect(
        [for (final s in groups.last.sessions) s.id],
        ['farewell', 'gone'],
      );
    });

    test('leaves out the group without a venue when every session has one', () {
      final groups = byVenue(event, [
        session('lunch', '2027-07-17T17:30:00Z', venueId: 'park'),
      ]);
      expect(groups.last.venue?.id, 'parking');
    });
  });

  test('venueOf finds the venue, or none when removed or not set', () {
    expect(
      venueOf(
        event,
        session('a', '2027-07-17T00:00:00Z', venueId: 'hall'),
      )?.name,
      'Garland Hall',
    );
    expect(
      venueOf(event, session('a', '2027-07-17T00:00:00Z', venueId: 'x')),
      isNull,
    );
    expect(venueOf(event, session('a', '2027-07-17T00:00:00Z')), isNull);
  });

  test('typeSuggestions are the types already used, once each, sorted', () {
    expect(
      typeSuggestions([
        session('a', '2027-07-17T00:00:00Z', type: 'Program'),
        session('b', '2027-07-17T00:00:00Z', type: 'Kids program'),
        session('c', '2027-07-17T00:00:00Z', type: 'program'),
        session('d', '2027-07-17T00:00:00Z'),
      ]),
      ['Kids program', 'Program'],
    );
  });

  group('mapLinkFor', () {
    test('uses the organizer\'s map link', () {
      const venue = EventVenue(
        id: 'v',
        name: 'Hall',
        address: '1 Main St',
        mapUrl: 'https://maps.example.com/hall',
      );
      expect(mapLinkFor(venue).toString(), 'https://maps.example.com/hall');
    });

    test('otherwise searches the address', () {
      const venue = EventVenue(
        id: 'v',
        name: 'Hall',
        address: '5101 N George Bush Hwy, Garland, TX',
      );
      final link = mapLinkFor(venue)!;
      expect(link.host, 'www.google.com');
      expect(
        link.queryParameters['query'],
        '5101 N George Bush Hwy, Garland, TX',
      );
    });

    test('is null while the address is to be announced', () {
      expect(mapLinkFor(const EventVenue(id: 'v', name: 'Park')), isNull);
    });
  });

  test('isWebLink accepts only http and https links', () {
    expect(isWebLink('https://maps.app.goo.gl/x'), isTrue);
    expect(isWebLink('http://example.com'), isTrue);
    expect(isWebLink('javascript:alert(1)'), isFalse);
    expect(isWebLink('maps.google.com'), isFalse);
    expect(isWebLink(''), isFalse);
  });
}
