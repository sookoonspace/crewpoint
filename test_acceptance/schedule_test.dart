import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/sessions_dao.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/schedule/data/session_repository.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// #81 (Req 48, 49): the convention's schedule from §1 of the v3 test, its
/// venues and directions, and a multi-day schedule of blocks.
void main() {
  late FakeFirebaseFirestore firestore;
  late AppDatabase db;
  late SessionRepository sessions;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    db = AppDatabase(NativeDatabase.memory());
    sessions = SessionRepository(dao: SessionsDao(db), firestore: firestore);
  });

  tearDown(() async {
    await sessions.dispose();
    await db.close();
  });

  const hall = EventVenue(
    id: 'hall',
    name: 'Garland Hall',
    address: '5101 N George Bush Hwy, Garland, TX 75040',
  );
  const park = EventVenue(
    id: 'park',
    name: 'Picnic park',
    directions: 'Location may change. Follow the signs on the day.',
  );
  const hotel = EventVenue(
    id: 'hotel',
    name: 'Hyatt Place Dallas/Garland/Richardson',
    address: '5101 N George Bush Hwy, Garland, TX 75040',
  );
  const parking = EventVenue(
    id: 'parking',
    name: 'Parking',
    address: '5101 N George Bush Hwy, Garland, TX 75040',
    mapUrl: 'https://maps.example.com/hyatt-parking',
    directions: 'Free parking behind the conference center.',
  );
  const convention = EventModel(
    id: 'conv',
    title: 'Convention 2027',
    creatorId: 'admin',
    timeZone: 'America/Chicago',
    venues: [hotel, hall, park, parking],
  );

  /// Saves a session at [hour]:[minute] on July [day] in Chicago.
  Future<String> add(
    EventModel event,
    String title,
    int day,
    int hour, {
    int minute = 0,
    String? venueId,
    String? type,
    bool locationTba = false,
    List<String> tags = const [],
    bool timeTbc = true,
    SessionEligibility eligibility = const SessionEligibility(),
  }) async {
    final (result, id) = await sessions.save(
      event.id,
      SessionModel(
        id: '',
        title: title,
        startAt: eventLocalToUtc(
          2027,
          7,
          day,
          event.timeZone,
          hour: hour,
          minute: minute,
        ),
        timeTbc: timeTbc,
        venueId: venueId,
        locationTba: locationTba,
        type: type,
        tags: tags,
        eligibility: eligibility,
      ),
      uid: 'admin',
    );
    expect(result, EventWriteResult.saved);
    return id;
  }

  Future<List<SessionModel>> loaded(String eventId, int count) => sessions
      .watchSessions(eventId, withHidden: true)
      .firstWhere((l) => l.length == count);

  test(
    'A-02 the §1 schedule, with programs, the kids activity, outdoor '
    'lunch, a location to be announced and editable placeholder times',
    () async {
      final ids = <String, String>{};
      Future<void> row(
        String code,
        String title,
        int day,
        int hour, {
        int minute = 0,
        String type = 'Meal',
        String? venueId = 'hall',
        List<String> tags = const [],
        bool locationTba = false,
        SessionEligibility eligibility = const SessionEligibility(),
      }) async => ids[code] = await add(
        convention,
        title,
        day,
        hour,
        minute: minute,
        type: type,
        venueId: venueId,
        tags: tags,
        locationTba: locationTba,
        eligibility: eligibility,
      );

      await row('M1', 'Welcome Dinner', 16, 19);
      await row('P1', 'Karaoke & Garba', 16, 21, type: 'Program');
      await row('M2', 'Breakfast', 17, 8);
      await row(
        'M3',
        'Lunch',
        17,
        12,
        minute: 30,
        venueId: 'park',
        tags: ['outdoor'],
      );
      await row(
        'K1',
        'Kids activities',
        17,
        13,
        minute: 30,
        type: 'Kids program',
        venueId: 'park',
        tags: ['outdoor'],
        eligibility: const SessionEligibility(categoryIds: ['child']),
      );
      await row('P2', 'Bhajan & Prasad', 17, 16, type: 'Program');
      await row('M4', 'Dinner', 17, 19);
      await row('P3', 'Karaoke & Garba', 17, 21, type: 'Program');
      await row('M5', 'Breakfast', 18, 8);
      await row('M6', 'Lunch', 18, 12, minute: 30);
      await row('M7', 'Gala Night Dinner + DJ', 18, 19);
      await row(
        'M8',
        'Farewell Breakfast',
        19,
        8,
        venueId: null,
        locationTba: true,
      );

      final all = await loaded('conv', 12);
      SessionModel byCode(String code) =>
          all.firstWhere((s) => s.id == ids[code]);

      // Four days, Friday to Monday, in the event's own zone.
      final days = byDay(convention, all);
      expect([for (final d in days) d.day.day], [16, 17, 18, 19]);
      expect([for (final d in days) d.sessions.length], [2, 6, 3, 1]);
      // Programs and the kids activity are on the schedule by type.
      expect(typeSuggestions(all), ['Kids program', 'Meal', 'Program']);
      expect(byCode('K1').eligibility.admits(categoryId: 'child'), isTrue);
      expect(byCode('K1').eligibility.admits(categoryId: 'adult'), isFalse);
      // M3 and K1 are flagged outdoor.
      expect(
        [
          for (final s in all)
            if (s.tags.contains('outdoor')) s.title,
        ]..sort(),
        ['Kids activities', 'Lunch'],
      );
      // M8's location is to be announced.
      expect(byCode('M8').locationTba, isTrue);
      expect(venueOf(convention, byCode('M8')), isNull);
      // Every time is a placeholder until the program is final.
      expect(all.every((s) => s.timeTbc), isTrue);

      // The program is final: M3 moves to 1 pm and is confirmed.
      await sessions.save(
        'conv',
        SessionModel(
          id: ids['M3']!,
          title: 'Lunch',
          startAt: eventLocalToUtc(2027, 7, 17, 'America/Chicago', hour: 13),
          venueId: 'park',
          type: 'Meal',
          tags: const ['outdoor'],
        ),
        uid: 'admin',
      );
      final m3 =
          (await firestore.doc('events/conv/sessions/${ids['M3']}').get())
              .data()!;
      expect(
        (m3['startAt'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2027, 7, 17, 18),
      );
      expect(m3['timeTbc'], isFalse);
    },
  );

  test('A-05 map and directions entries for the hotel, Garland Hall, the '
      'picnic park (to be announced) and parking', () async {
    final repo = EventRepository(
      eventsDao: EventsDao(db),
      firestore: firestore,
      createEventCall: (_, {savedTemplateId}) async =>
          throw UnimplementedError(),
    );
    await firestore.doc('events/conv').set({'title': convention.title});
    await repo.saveConfiguration(convention);
    final stored = [
      for (final v
          in ((await firestore.doc('events/conv').get()).data()!['venues']
              as List<dynamic>))
        EventVenue.fromMap((v as Map).cast<String, dynamic>()),
    ];
    expect(stored, [hotel, hall, park, parking]);

    // Hotel and hall open a map search for their address.
    for (final v in [stored[0], stored[1]]) {
      expect(mapLinkFor(v)!.queryParameters['query'], v.address);
    }
    // The picnic park is to be announced, with directions and no map yet.
    expect(stored[2].addressTba, isTrue);
    expect(mapLinkFor(stored[2]), isNull);
    expect(stored[2].directions, isNotEmpty);
    // Parking uses the organizer's own map link, with directions.
    expect(
      mapLinkFor(stored[3]).toString(),
      'https://maps.example.com/hyatt-parking',
    );
    expect(stored[3].directions, 'Free parking behind the conference center.');

    // By venue, every entry is listed, even with no sessions there.
    expect(
      [for (final g in byVenue(convention, const [])) g.venue?.id],
      ['hotel', 'hall', 'park', 'parking'],
    );
  });

  test('GAP-WED-12 a multi-day schedule of blocks across venues', () async {
    const wedding = EventModel(
      id: 'wed',
      title: 'Asha and Dev',
      creatorId: 'asha',
      timeZone: 'America/Toronto',
      venues: [
        EventVenue(id: 'home', name: 'Family home', address: '12 Elm St'),
        EventVenue(id: 'temple', name: 'Temple', address: '1 Temple Rd'),
        EventVenue(id: 'banquet', name: 'Banquet hall', address: '9 King St'),
      ],
    );
    await add(
      wedding,
      'Mehndi',
      21,
      18,
      venueId: 'home',
      type: 'Mehndi',
      timeTbc: false,
    );
    await add(wedding, 'Getting ready', 22, 8, venueId: 'home', timeTbc: false);
    await add(
      wedding,
      'Ceremony',
      22,
      11,
      venueId: 'temple',
      type: 'Ceremony',
      timeTbc: false,
    );
    await add(
      wedding,
      'Reception',
      22,
      18,
      venueId: 'banquet',
      type: 'Reception',
      timeTbc: false,
    );

    final all = await loaded('wed', 4);
    final days = byDay(wedding, all);
    expect([for (final d in days) d.day.day], [21, 22]);
    expect(
      [for (final s in days.last.sessions) s.title],
      ['Getting ready', 'Ceremony', 'Reception'],
    );
    final venues = byVenue(wedding, all);
    expect([for (final g in venues) g.sessions.length], [2, 1, 1]);
  });

  test('A-01 venues hold an address, map link and directions', () {
    expect(hall.toMap(), {
      'id': 'hall',
      'name': 'Garland Hall',
      'address': '5101 N George Bush Hwy, Garland, TX 75040',
      'mapUrl': null,
      'directions': null,
    });
    expect(EventVenue.fromMap(parking.toMap()), parking);
  });
}
