import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/large_event.dart';

/// Req 43a: past 50 members, an equal split needs choosing who shares it,
/// and the balance card shows you and the largest balances, so a large event
/// never reads or draws everyone.
void main() {
  group('choosing who shares an equal split', () {
    test('everyone by default up to 50 members', () {
      expect(splitNeedsChoosing(1), isFalse);
      expect(splitNeedsChoosing(50), isFalse);
    });

    test('choosing once an event passes 50 members', () {
      expect(splitNeedsChoosing(51), isTrue);
      expect(splitNeedsChoosing(5000), isTrue);
    });
  });

  group('balances shown', () {
    final balances = {
      for (var i = 0; i < 60; i++) 'u$i': i.isEven ? i * 1.0 : -i * 1.0,
      'zero': 0.0,
      'me': 0.001,
    };

    test('everyone up to 50 members, zero balances included', () {
      final small = {'a': 5.0, 'b': -5.0, 'c': 0.0};
      expect(shownBalanceUids(small, me: 'a', memberCount: 3), {'a', 'b', 'c'});
    });

    test('past 50 members: you and the 20 largest, either way', () {
      final shown = shownBalanceUids(balances, me: 'me', memberCount: 62);
      expect(shown, hasLength(21));
      expect(shown, contains('me'));
      expect(shown, containsAll(['u59', 'u58', 'u40']));
      expect(shown, isNot(contains('u39')));
      expect(shown, isNot(contains('zero')));
    });

    test('past 50 members, you are left out only when you have no balance', () {
      final shown = shownBalanceUids(balances, me: 'nobody', memberCount: 62);
      expect(shown, hasLength(largeEventTopBalances));
    });
  });

  group('transfers shown', () {
    final transfers = [
      for (var i = 0; i < 40; i++)
        Settlement(fromUserId: 'u$i', toUserId: 'host', amount: i + 1.0),
      const Settlement(fromUserId: 'me', toUserId: 'host', amount: 0.5),
      const Settlement(fromUserId: 'host', toUserId: 'me', amount: 0.25),
    ];

    test('all of them up to 50 members', () {
      expect(
        shownSettlements(transfers, me: 'me', memberCount: 50),
        transfers,
      );
    });

    test('past 50 members: yours and the 20 largest, largest first', () {
      final shown = shownSettlements(transfers, me: 'me', memberCount: 51);
      expect(shown, hasLength(22));
      expect(shown.first.amount, 40);
      expect(shown.where((s) => s.fromUserId == 'u19'), isEmpty);
      expect(shown.where((s) => s.fromUserId == 'me'), hasLength(1));
      expect(shown.where((s) => s.toUserId == 'me'), hasLength(1));
    });
  });

  test('names are read for payers and the rows shown only', () {
    final ledger = BalanceLedger(
      netBalances: {
        for (var i = 0; i < 60; i++) 'u$i': i.toDouble(),
        'me': -1,
      },
      settlements: const [
        Settlement(fromUserId: 'me', toUserId: 'u59', amount: 1),
      ],
      totalExpenses: 10,
    );
    final uids = budgetNameUids(
      expenses: [
        const ExpenseModel(id: 'x', eventId: 'e', payerId: 'payer', amount: 1),
      ],
      ledger: ledger,
      me: 'me',
      memberCount: 61,
    );
    expect(uids, containsAll(['payer', 'me', 'u59', 'u40']));
    expect(uids, isNot(contains('u39')));
    // The payer, you and the 20 largest, u59 among them.
    expect(uids, hasLength(22));
  });
}
