import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

const _event = EventModel(
  id: 'e',
  title: 'Trip',
  creatorId: 'owner',
  adminIds: ['admin', 'admin2'],
  memberIds: ['owner', 'admin', 'admin2', 'member', 'other'],
);

bool can(String actor, String target) =>
    _event.canRemoveMember(actor: actor, target: target);

void main() {
  group('canRemoveMember matches removeEventMember', () {
    test('the owner can remove admins and members', () {
      expect(can('owner', 'admin'), isTrue);
      expect(can('owner', 'member'), isTrue);
    });

    test('an admin can remove a member', () {
      expect(can('admin', 'member'), isTrue);
    });

    test('an admin cannot remove another admin', () {
      expect(can('admin', 'admin2'), isFalse);
    });

    test('nobody can remove the owner', () {
      expect(can('admin', 'owner'), isFalse);
      expect(can('member', 'owner'), isFalse);
    });

    test('a member cannot remove anyone', () {
      expect(can('member', 'other'), isFalse);
      expect(can('member', 'admin'), isFalse);
    });

    test('removing yourself is leaving, not removing', () {
      expect(can('owner', 'owner'), isFalse);
      expect(can('admin', 'admin'), isFalse);
    });
  });
}
