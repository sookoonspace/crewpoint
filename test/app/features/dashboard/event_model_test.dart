import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

void main() {
  group('permissions (#66)', () {
    const arrays = EventModel(
      id: 'e1',
      title: 'Fest',
      creatorId: 'owner',
      adminIds: ['owner', 'admin'],
      memberIds: ['owner', 'admin', 'plain'],
    );

    test("the viewer's own member document decides", () {
      final finance = arrays.copyWithAccess(
        viewerId: 'plain',
        roleIds: const ['finance'],
        permissions: const {'money.record', 'chat.send'},
      );
      expect(finance.can('plain', 'money.record'), isTrue);
      expect(finance.can('plain', 'event.manage'), isFalse);
    });

    test('a role change while the screen is open shows straight away', () {
      final before = arrays.copyWithAccess(
        viewerId: 'plain',
        roleIds: const ['participant'],
        permissions: const {'chat.send'},
      );
      final after = before.copyWithAccess(
        viewerId: 'plain',
        roleIds: const ['crewLead'],
        permissions: const {'tasks.manage', 'chat.send'},
      );
      expect(before.can('plain', 'tasks.manage'), isFalse);
      expect(after.can('plain', 'tasks.manage'), isTrue);
    });

    test(
      'without a member document, the old arrays map as the server does',
      () {
        expect(arrays.can('owner', 'event.transfer'), isTrue);
        expect(arrays.can('admin', 'event.manage'), isTrue);
        expect(arrays.can('admin', 'roles.manage'), isFalse);
        expect(arrays.can('admin', 'event.transfer'), isFalse);
        expect(arrays.can('plain', 'chat.send'), isTrue);
        expect(arrays.can('plain', 'event.manage'), isFalse);
        expect(arrays.can('stranger', 'chat.send'), isFalse);
      },
    );

    test('Observer and Vendor do not contribute, and everyone else does', () {
      EventModel as(List<String> roles) => arrays.copyWithAccess(
        viewerId: 'plain',
        roleIds: roles,
        permissions: const {},
      );
      expect(as(const ['observer']).contributes('plain'), isFalse);
      expect(as(const ['vendor', 'observer']).contributes('plain'), isFalse);
      expect(as(const ['vendor', 'scorer']).contributes('plain'), isTrue);
      expect(arrays.contributes('plain'), isTrue);
      expect(arrays.contributes('stranger'), isFalse);
    });

    group('what a Vendor or Observer reads (Req 32)', () {
      EventModel as(List<String> roles, Set<String> permissions) =>
          arrays.copyWithAccess(
            viewerId: 'plain',
            roleIds: roles,
            permissions: permissions,
          );

      test('only their own tasks, unless the role holds tasks.manage', () {
        expect(as(const ['vendor'], const {}).readsAllTasks('plain'), isFalse);
        expect(
          as(const ['vendor'], const {'tasks.manage'}).readsAllTasks('plain'),
          isTrue,
        );
        expect(
          as(const ['participant'], const {}).readsAllTasks('plain'),
          isTrue,
        );
      });

      test(
        'only their own expenses, unless money.read or expenses.readAll',
        () {
          expect(
            as(const ['observer'], const {}).readsAllExpenses('plain'),
            isFalse,
          );
          expect(
            as(
              const ['observer'],
              const {'money.read'},
            ).readsAllExpenses('plain'),
            isTrue,
          );
          expect(
            as(
              const ['vendor'],
              const {'expenses.readAll'},
            ).readsAllExpenses('plain'),
            isTrue,
          );
          expect(arrays.readsAllExpenses('plain'), isTrue);
        },
      );

      test('chat only with chat.send', () {
        expect(as(const ['vendor'], const {}).readsChat('plain'), isFalse);
        expect(
          as(const ['observer'], const {'chat.send'}).readsChat('plain'),
          isTrue,
        );
        expect(arrays.readsChat('plain'), isTrue);
      });
    });

    test('a draft is visible only with event.manage', () {
      final draft = arrays.copyWithAccess(
        viewerId: 'plain',
        roleIds: const ['custom'],
        permissions: const {'event.manage'},
      );
      expect(
        const EventModel(
          id: 'e',
          title: 'T',
          creatorId: 'o',
          status: EventStatus.draft,
        ).isVisibleTo('x'),
        isFalse,
      );
      expect(
        draft.copyWith(status: EventStatus.draft).isVisibleTo('plain'),
        isTrue,
      );
    });
  });

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

    test('admins map to Admin, without transfer or roles', () {
      expect(event.can('admin1', 'event.manage'), isTrue);
      expect(event.can('admin1', 'roles.manage'), isFalse);
      expect(event.can('member1', 'event.manage'), isFalse);
      expect(event.can('stranger', 'chat.send'), isFalse);
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
      expect(event.modules, {
        'tasks': true,
        'budget': true,
        'chat': true,
        'schedule': true,
      });
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

    test('the schedule needs schedule.edit, the module, and an open event', () {
      expect(at(EventStatus.live).canEditSchedule('admin'), isTrue);
      expect(at(EventStatus.draft).canEditSchedule('owner'), isTrue);
      expect(at(EventStatus.live).canEditSchedule('member'), isFalse);
      expect(at(EventStatus.ended).canEditSchedule('owner'), isTrue);
      expect(at(EventStatus.archived).canEditSchedule('owner'), isFalse);
      expect(
        at(
          EventStatus.live,
        ).copyWith(modules: const {'schedule': false}).canEditSchedule('owner'),
        isFalse,
      );
    });

    test('reads its attendance policy, everyone by default (Req 50)', () {
      expect(at(EventStatus.live).attendancePolicy, AttendancePolicy.everyone);
      expect(
        const EventModel(
          id: 'e1',
          title: 'T',
          creatorId: 'owner',
          settings: {'attendancePolicy': 'invitedOnly'},
        ).attendancePolicy,
        AttendancePolicy.invitedOnly,
      );
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

  // Req 43a: the server keeps memberCount, so large events never count the
  // member array.
  group('memberCount', () {
    test('is the server count when there is one', () {
      const event = EventModel(
        id: 'e',
        title: 'T',
        creatorId: 'a',
        memberIds: ['a', 'b'],
        memberCount: 1200,
      );
      expect(event.memberCount, 1200);
      expect(event.copyWith(title: 'U').memberCount, 1200);
    });

    test('falls back to the member array on older events', () {
      const event = EventModel(
        id: 'e',
        title: 'T',
        creatorId: 'a',
        memberIds: ['a', 'b'],
      );
      expect(event.memberCount, 2);
    });
  });
}
