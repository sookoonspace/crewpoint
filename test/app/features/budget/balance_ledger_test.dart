import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

void main() {
  const members = ['alice', 'bob', 'charlie'];

  group('BalanceLedger.calculate', () {
    test('3 members, equal split — each balance is correct', () {
      // Alice pays $90 dinner, split 3 ways
      final expenses = [
        const ExpenseModel(
          id: 'e1',
          eventId: 'ev1',
          payerId: 'alice',
          amount: 90,
        ),
      ];

      final ledger = BalanceLedger.calculate(
        expenses: expenses,
        memberIds: members,
      );

      // Alice paid 90, owes 30 → net +60
      expect(ledger.netBalances['alice'], equals(60.0));
      // Bob paid 0, owes 30 → net -30
      expect(ledger.netBalances['bob'], equals(-30.0));
      // Charlie paid 0, owes 30 → net -30
      expect(ledger.netBalances['charlie'], equals(-30.0));
      expect(ledger.totalExpenses, equals(90.0));
    });

    test('one person pays all 3 expenses — other 2 owe them', () {
      final expenses = [
        const ExpenseModel(
          id: 'e1',
          eventId: 'ev1',
          payerId: 'alice',
          amount: 30,
        ),
        const ExpenseModel(
          id: 'e2',
          eventId: 'ev1',
          payerId: 'alice',
          amount: 60,
        ),
        const ExpenseModel(
          id: 'e3',
          eventId: 'ev1',
          payerId: 'alice',
          amount: 30,
        ),
      ];

      final ledger = BalanceLedger.calculate(
        expenses: expenses,
        memberIds: members,
      );

      // Total 120, each owes 40. Alice paid 120, owes 40 → net +80
      expect(ledger.netBalances['alice'], equals(80.0));
      expect(ledger.netBalances['bob'], equals(-40.0));
      expect(ledger.netBalances['charlie'], equals(-40.0));
    });

    test('donation expense — payer excluded from their own split', () {
      final expenses = [
        const ExpenseModel(
          id: 'e1',
          eventId: 'ev1',
          payerId: 'alice',
          amount: 100,
          isDonation: true,
        ),
      ];

      final ledger = BalanceLedger.calculate(
        expenses: expenses,
        memberIds: members,
      );

      // Alice donates: pays 100, split only among bob+charlie (50 each)
      // Alice net: +100 (paid) - 0 (not in split) = +100
      expect(ledger.netBalances['alice'], equals(100.0));
      expect(ledger.netBalances['bob'], equals(-50.0));
      expect(ledger.netBalances['charlie'], equals(-50.0));
    });

    test('payment expense — reduces payer debt, increases recipient balance', () {
      final expenses = [
        // Alice pays $90 dinner
        const ExpenseModel(
          id: 'e1',
          eventId: 'ev1',
          payerId: 'alice',
          amount: 90,
        ),
        // Bob settles his $30 debt by paying Alice
        const ExpenseModel(
          id: 'p1',
          eventId: 'ev1',
          payerId: 'bob',
          amount: 30,
          isPayment: true,
          splits: [ExpenseSplit(userId: 'alice', amount: 30)],
        ),
      ];

      final ledger = BalanceLedger.calculate(
        expenses: expenses,
        memberIds: members,
      );

      // Alice: +90 (paid dinner) -30 (her share) -30 (received payment) = +30
      expect(ledger.netBalances['alice'], equals(30.0));
      // Bob: -30 (his share) -30 (paid to alice) +30 (received in payment accounting)
      // Wait — payment: bob's balance decreases by 30, alice's increases by 30
      // So Bob: 0 (paid nothing for dinner) - 30 (his share) - 30 (payment out) = ...
      // Let me recalculate:
      // Dinner: alice +90, alice -30, bob -30, charlie -30
      // Payment: bob -30, alice +30
      // Net: alice = 90-30+30 = 90... hmm

      // Actually:
      // After dinner: alice=+60, bob=-30, charlie=-30
      // Payment adds: bob=-30 (pays out), alice=+30 (receives)
      // Net: alice=60+30=90... that's wrong. Let me re-think.

      // The payment should REDUCE alice's credit and REDUCE bob's debt.
      // When bob pays alice $30, it's like bob covered $30 of what alice fronted.
      // In the ledger: bob's balance goes from -30 to 0, alice's goes from +60 to +30.

      // In our model: isPayment means bob pays alice directly.
      // balances[bob] -= 30 (he spent money outward)
      // balances[alice] += 30 (she received money)
      // But alice already has +60 from the dinner...
      // So alice = +60 + 30 = +90? That makes the debt WORSE.

      // The issue: for a payment, we should NOT add to the recipient's balance.
      // A payment from bob to alice should:
      //   bob: pays 30 to alice → bob.balance += 30 (he "paid for" alice)
      //   alice: received 30 from bob → alice.balance -= 30 (she "owes" 30 less)

      // Actually no — think of it like Splitwise:
      // A payment is an expense where bob pays $30, split only with alice.
      // bob.balance += 30 (paid), alice.balance -= 30 (owes that share)
      // After dinner: alice=+60, bob=-30, charlie=-30
      // After payment (bob pays 30, split=[alice]): bob += 30 → 0, alice -= 30 → +30
      // alice=+30, bob=0, charlie=-30 ✓

      // So isPayment should work like a REGULAR expense, not a direct transfer!
      // payer.balance += amount, recipient.balance -= amount (as a split)

      // My implementation has it backwards. Let me fix the test expectation
      // to match the CORRECT behavior, then fix the code.

      // Correct: alice=+30, bob=0, charlie=-30
      expect(ledger.netBalances['bob'], equals(0.0));
      expect(ledger.netBalances['charlie'], equals(-30.0));
    });

    test('mixed scenario — expenses + donations + payments', () {
      final expenses = [
        // Alice pays $90 dinner (split 3 ways)
        const ExpenseModel(
          id: 'e1',
          eventId: 'ev1',
          payerId: 'alice',
          amount: 90,
        ),
        // Bob pays $30 taxi (split 3 ways)
        const ExpenseModel(
          id: 'e2',
          eventId: 'ev1',
          payerId: 'bob',
          amount: 30,
        ),
        // Charlie settles with alice: pays $20
        const ExpenseModel(
          id: 'p1',
          eventId: 'ev1',
          payerId: 'charlie',
          amount: 20,
          isPayment: true,
          splits: [ExpenseSplit(userId: 'alice', amount: 20)],
        ),
      ];

      final ledger = BalanceLedger.calculate(
        expenses: expenses,
        memberIds: members,
      );

      // Dinner: alice +90-30=+60, bob -30, charlie -30
      // Taxi: bob +30-10=+20, alice -10→+50, charlie -10→-40
      // After expenses: alice=+50, bob=-10, charlie=-40
      // Payment (charlie pays 20, split=[alice]):
      //   charlie += 20 → -20, alice -= 20 → +30
      // Final: alice=+30, bob=-10, charlie=-20
      expect(ledger.netBalances['alice'], equals(30.0));
      expect(ledger.netBalances['bob'], equals(-10.0));
      expect(ledger.netBalances['charlie'], equals(-20.0));
      expect(ledger.totalExpenses, equals(120.0)); // 90+30, payment not counted
    });

    test('simplification — 4 members, mixed expenses → minimum transfers', () {
      final fourMembers = ['a', 'b', 'c', 'd'];
      final expenses = [
        // A pays $100 (split 4 ways: each owes 25)
        const ExpenseModel(id: 'e1', eventId: 'ev1', payerId: 'a', amount: 100),
        // B pays $60 (split 4 ways: each owes 15)
        const ExpenseModel(id: 'e2', eventId: 'ev1', payerId: 'b', amount: 60),
      ];

      final ledger = BalanceLedger.calculate(
        expenses: expenses,
        memberIds: fourMembers,
      );

      // A: +100-25-15 = +60
      // B: +60-25-15 = +20
      // C: -25-15 = -40
      // D: -25-15 = -40
      expect(ledger.netBalances['a'], equals(60.0));
      expect(ledger.netBalances['b'], equals(20.0));
      expect(ledger.netBalances['c'], equals(-40.0));
      expect(ledger.netBalances['d'], equals(-40.0));

      // Settlements should be ≤ 3 transfers (greedy)
      expect(ledger.settlements.length, lessThanOrEqualTo(3));

      // Total settled amount should equal total debt
      final totalSettled = ledger.settlements.fold(
        0.0,
        (sum, s) => sum + s.amount,
      );
      expect(totalSettled, equals(80.0));
    });

    test('empty expenses → all balances zero, no settlements', () {
      final ledger = BalanceLedger.calculate(expenses: [], memberIds: members);

      expect(ledger.netBalances['alice'], equals(0.0));
      expect(ledger.netBalances['bob'], equals(0.0));
      expect(ledger.netBalances['charlie'], equals(0.0));
      expect(ledger.settlements, isEmpty);
      expect(ledger.totalExpenses, equals(0.0));
    });
  });
}
