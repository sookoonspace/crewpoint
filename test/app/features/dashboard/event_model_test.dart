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

  group('EventStatus', () {
    test('fromString parses active and archived', () {
      expect(EventStatus.fromString('active'), equals(EventStatus.active));
      expect(EventStatus.fromString('archived'), equals(EventStatus.archived));
    });

    test('fromString defaults to active for unknown values', () {
      expect(EventStatus.fromString('completed'), equals(EventStatus.active));
      expect(EventStatus.fromString(null), equals(EventStatus.active));
    });

    test('name serializes correctly', () {
      expect(EventStatus.active.name, equals('active'));
      expect(EventStatus.archived.name, equals('archived'));
    });
  });

  group('EventModel with Drift round-trip', () {
    test('adminIds and memberIds default to empty lists', () {
      const event = EventModel(id: 'e1', title: 'Test', creatorId: 'u1');

      expect(event.adminIds, isEmpty);
      expect(event.memberIds, isEmpty);
      expect(event.templateId, equals('blank'));
      expect(event.status, equals(EventStatus.active));
      expect(event.startDate, isNull);
    });
  });
}
