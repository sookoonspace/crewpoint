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

  group('EventType', () {
    test('fromString parses known types', () {
      expect(EventType.fromString('trip'), equals(EventType.trip));
      expect(EventType.fromString('project'), equals(EventType.project));
      expect(EventType.fromString('social'), equals(EventType.social));
      expect(EventType.fromString('custom'), equals(EventType.custom));
    });

    test('fromString defaults to custom for unknown values', () {
      expect(EventType.fromString('unknown'), equals(EventType.custom));
      expect(EventType.fromString(null), equals(EventType.custom));
    });

    test('label returns human-readable name', () {
      expect(EventType.trip.label, equals('Trip'));
      expect(EventType.project.label, equals('Project'));
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
      expect(event.eventType, equals(EventType.custom));
      expect(event.status, equals(EventStatus.active));
      expect(event.startDate, isNull);
    });
  });
}
