import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

void main() {
  group('EventModel role helpers', () {
    const event = EventModel(
      id: 'e1',
      title: 'Trip',
      creatorId: 'owner',
      adminIds: ['owner', 'admin1'],
      memberIds: ['owner', 'admin1', 'member1', 'member2'],
    );

    test('isOwner returns true only for creator', () {
      expect(event.isOwner('owner'), isTrue);
      expect(event.isOwner('admin1'), isFalse);
      expect(event.isOwner('member1'), isFalse);
      expect(event.isOwner('stranger'), isFalse);
    });

    test('isAdmin returns true for creator and adminIds', () {
      expect(event.isAdmin('owner'), isTrue);
      expect(event.isAdmin('admin1'), isTrue);
      expect(event.isAdmin('member1'), isFalse);
      expect(event.isAdmin('stranger'), isFalse);
    });

    test('isMember returns true for anyone in memberIds', () {
      expect(event.isMember('owner'), isTrue);
      expect(event.isMember('admin1'), isTrue);
      expect(event.isMember('member1'), isTrue);
      expect(event.isMember('member2'), isTrue);
      expect(event.isMember('stranger'), isFalse);
    });
  });

  group('configuration (Req 18, 21)', () {
    const event = EventModel(id: 'e1', title: 'Only a title', creatorId: 'u1');

    test('a new event needs only a title', () {
      expect(event.templateId, 'blank');
      expect(event.displayType, isNull);
      expect(event.organizerId, isNull);
      expect(event.timeZone, 'UTC');
      expect(event.venues, isEmpty);
      expect(event.currency, 'USD');
      expect(event.languages, ['en']);
      expect(event.modules, {'tasks': true, 'budget': true, 'chat': true});
      expect(event.labels, isEmpty);
      expect(event.settings, isEmpty);
      expect(event.capacity, isNull);
      expect(event.memberLimit, isNull);
    });

    test('an old type name is display text only', () {
      const old = EventModel(
        id: 'e1',
        title: 'Tahoe',
        creatorId: 'u1',
        displayType: 'trip',
      );
      expect(old.typeLabel, 'Trip');
      expect(old.templateId, 'blank');
      expect(event.typeLabel, isNull);
    });

    test('a module is on unless turned off', () {
      expect(event.isModuleOn('tasks'), isTrue);
      const off = EventModel(
        id: 'e1',
        title: 'T',
        creatorId: 'u1',
        modules: {'tasks': false},
      );
      expect(off.isModuleOn('tasks'), isFalse);
      expect(off.isModuleOn('chat'), isTrue);
    });

    test('capacity and member limit can be set and cleared', () {
      final set = event.copyWith(capacity: 500, memberLimit: 100);
      expect(set.capacity, 500);
      expect(set.memberLimit, 100);
      final kept = set.copyWith(title: 'New');
      expect(kept.capacity, 500);
      expect(kept.memberLimit, 100);
      final cleared = set.copyWith(clearCapacity: true, clearMemberLimit: true);
      expect(cleared.capacity, isNull);
      expect(cleared.memberLimit, isNull);
    });

    test('event.manage means owner or admin until permissions land', () {
      const managed = EventModel(
        id: 'e1',
        title: 'T',
        creatorId: 'owner',
        adminIds: ['admin'],
        memberIds: ['owner', 'admin', 'member'],
      );
      expect(managed.canManage('owner'), isTrue);
      expect(managed.canManage('admin'), isTrue);
      expect(managed.canManage('member'), isFalse);
    });

    test('venues compare by value and survive a round trip', () {
      const venue = EventVenue(id: 'v', name: 'Hall', address: '1 Main St');
      expect(EventVenue.fromMap(venue.toMap()), venue);
      expect(
        EventVenue.fromMap(const {'id': 'v', 'name': 'Hall'}).address,
        isNull,
      );
    });
  });

  group('EventStatus (Req 19)', () {
    final now = DateTime.utc(2027, 6, 1);

    test('reads the five statuses', () {
      for (final status in EventStatus.values) {
        expect(EventStatus.fromStored(status.name, null, now), status);
      }
      expect(EventStatus.values.map((s) => s.name), [
        'draft',
        'published',
        'live',
        'ended',
        'archived',
      ]);
    });

    test('active maps to ended once the end date has passed', () {
      final past = DateTime.utc(2027, 5, 1);
      expect(EventStatus.fromStored('active', past, now), EventStatus.ended);
    });

    test('active maps to published otherwise', () {
      final future = DateTime.utc(2027, 7, 1);
      expect(
        EventStatus.fromStored('active', future, now),
        EventStatus.published,
      );
      expect(
        EventStatus.fromStored('active', null, now),
        EventStatus.published,
      );
      expect(EventStatus.fromStored(null, null, now), EventStatus.published);
    });
  });

  group('what each status allows (GE-08)', () {
    EventModel at(EventStatus status) => EventModel(
      id: 'e1',
      title: 'T',
      creatorId: 'owner',
      adminIds: const ['admin'],
      memberIds: const ['owner', 'admin', 'member'],
      status: status,
    );

    test('a draft is visible only to organizers', () {
      final draft = at(EventStatus.draft);
      expect(draft.isVisibleTo('owner'), isTrue);
      expect(draft.isVisibleTo('admin'), isTrue);
      expect(draft.isVisibleTo('member'), isFalse);
      expect(at(EventStatus.published).isVisibleTo('member'), isTrue);
    });

    test('only published and live are open to joining', () {
      for (final status in EventStatus.values) {
        expect(
          at(status).isJoinable,
          status == EventStatus.published || status == EventStatus.live,
          reason: status.name,
        );
      }
    });

    test('chat and money stay open until archived', () {
      for (final status in EventStatus.values) {
        expect(
          at(status).allowsChatAndMoney,
          status != EventStatus.archived,
          reason: status.name,
        );
      }
    });

    test('tasks close to members once ended, and to all once archived', () {
      expect(at(EventStatus.live).canEditTasks('member'), isTrue);
      expect(at(EventStatus.ended).canEditTasks('member'), isFalse);
      expect(at(EventStatus.ended).canEditTasks('admin'), isTrue);
      expect(at(EventStatus.archived).canEditTasks('owner'), isFalse);
    });

    test('an event can go back to draft only with no plain members', () {
      expect(at(EventStatus.published).canBeDraft, isFalse);
      expect(
        const EventModel(
          id: 'e1',
          title: 'T',
          creatorId: 'owner',
          adminIds: ['admin'],
          memberIds: ['owner', 'admin'],
        ).canBeDraft,
        isTrue,
      );
    });

    test('restoring goes to ended after the end date, or else published', () {
      final now = DateTime.utc(2027, 6, 1);
      expect(
        at(
          EventStatus.archived,
        ).copyWith(endDate: DateTime.utc(2027, 5, 1)).restoredStatus(now),
        EventStatus.ended,
      );
      expect(
        at(EventStatus.archived).restoredStatus(now),
        EventStatus.published,
      );
    });
  });

  group('EventModel with Drift round-trip', () {
    test('adminIds and memberIds default to empty lists', () {
      const event = EventModel(id: 'e1', title: 'Test', creatorId: 'u1');

      expect(event.adminIds, isEmpty);
      expect(event.memberIds, isEmpty);
      expect(event.templateId, equals('blank'));
      expect(event.status, equals(EventStatus.published));
      expect(event.startDate, isNull);
    });
  });
}
