import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/expense_access.dart';

/// Req 38 (L15): mirrors `functions/src/events/expenseAccess.ts`, so the
/// settings screen can say who will lose access before saving.
void main() {
  group('ExpenseAccess.fromMap', () {
    test('missing is Everyone, leaving out Observers and Vendors', () {
      expect(ExpenseAccess.fromMap(null), const ExpenseAccess.everyone());
      expect(
        ExpenseAccess.fromMap(const {'mode': 'nonsense'}).mode,
        ExpenseAccessMode.everyone,
      );
    });

    test('reads each option, keeping only what it uses', () {
      expect(
        ExpenseAccess.fromMap(const {
          'mode': 'selected',
          'roleIds': ['finance', 3],
          'uids': ['pat'],
          'includeNonContributors': true,
        }),
        const ExpenseAccess(
          mode: ExpenseAccessMode.selected,
          roleIds: ['finance'],
          uids: ['pat'],
        ),
      );
      expect(
        ExpenseAccess.fromMap(const {
          'mode': 'everyone',
          'includeNonContributors': true,
        }).includeNonContributors,
        isTrue,
      );
    });

    test('round-trips through the map the callable takes', () {
      const access = ExpenseAccess(
        mode: ExpenseAccessMode.selected,
        roleIds: ['crewLead'],
        uids: ['sam'],
      );
      expect(ExpenseAccess.fromMap(access.toMap()), access);
    });
  });

  group('readsAll', () {
    test('Everyone: every member except Observers and Vendors', () {
      const access = ExpenseAccess.everyone();
      expect(access.readsAll('a', const ['participant']), isTrue);
      expect(access.readsAll('a', const ['vendor', 'scorer']), isTrue);
      expect(access.readsAll('a', const ['observer']), isFalse);
      const all = ExpenseAccess.everyone(includeNonContributors: true);
      expect(all.readsAll('a', const ['vendor']), isTrue);
    });

    test('Only people involved: nobody', () {
      const access = ExpenseAccess(mode: ExpenseAccessMode.involved);
      expect(access.readsAll('a', const ['owner']), isFalse);
    });

    test('Selected: the chosen roles and people', () {
      const access = ExpenseAccess(
        mode: ExpenseAccessMode.selected,
        roleIds: ['crewLead'],
        uids: ['pat'],
      );
      expect(access.readsAll('a', const ['crewLead']), isTrue);
      expect(access.readsAll('pat', const ['participant']), isTrue);
      expect(access.readsAll('b', const ['participant']), isFalse);
    });
  });

  group('on an event', () {
    const event = EventModel(
      id: 'e',
      title: 'Fest',
      creatorId: 'owner',
      adminIds: ['owner'],
      memberIds: ['owner', 'plain'],
      settings: {
        'expenseAccess': {'mode': 'involved'},
      },
    );

    test('reads the setting', () {
      expect(event.expenseAccess.mode, ExpenseAccessMode.involved);
    });

    test('reading every expense follows the permission, not the role', () {
      expect(event.readsAllExpenses('plain'), isFalse);
      expect(event.readsAllExpenses('owner'), isTrue);
      final widened = event.copyWithAccess(
        viewerId: 'plain',
        roleIds: const ['participant'],
        permissions: const {'chat.send', 'expenses.readAll'},
      );
      expect(widened.readsAllExpenses('plain'), isTrue);
    });

    test('an older event without member documents follows the setting', () {
      const everyone = EventModel(
        id: 'e',
        title: 'Fest',
        creatorId: 'owner',
        memberIds: ['owner', 'plain'],
      );
      expect(everyone.readsAllExpenses('plain'), isTrue);
    });
  });
}
