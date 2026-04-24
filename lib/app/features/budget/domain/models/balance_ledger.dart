import 'dart:math';

import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

/// Computed balance ledger for an event — NOT persisted to Firestore.
class BalanceLedger {
  const BalanceLedger({
    required this.netBalances,
    required this.settlements,
    required this.totalExpenses,
  });

  /// uid → net amount (positive = owed money, negative = owes money)
  final Map<String, double> netBalances;

  /// Minimum transfers needed to settle all debts (computed, not stored)
  final List<Settlement> settlements;

  /// Sum of all non-payment expenses
  final double totalExpenses;

  /// Calculates net balances and simplified settlements from event expenses.
  static BalanceLedger calculate({
    required List<ExpenseModel> expenses,
    required List<String> memberIds,
  }) {
    // Initialize balances at zero
    final balances = <String, double>{for (final id in memberIds) id: 0.0};

    var totalExpenses = 0.0;

    for (final expense in expenses) {
      if (expense.isPayment) {
        // Payment: treated like a regular expense where the payer
        // "paid for" the recipient. This naturally reduces the
        // payer's debt and the recipient's credit in the ledger.
        // payer.balance += amount (they fronted money)
        // recipient.balance -= amount (their share of what was "paid")
        balances[expense.payerId] =
            (balances[expense.payerId] ?? 0) + expense.amount;
        for (final split in expense.splits) {
          balances[split.userId] = (balances[split.userId] ?? 0) - split.amount;
        }
        // Payments don't count toward totalExpenses
      } else {
        // Regular expense or donation
        totalExpenses += expense.amount;

        // Payer's balance increases (they paid for others)
        balances[expense.payerId] =
            (balances[expense.payerId] ?? 0) + expense.amount;

        // Each member in split owes their share
        final splitMembers = expense.splits.isNotEmpty
            ? expense.splits
            : ExpenseModel.calculateSplits(
                amount: expense.amount,
                payerId: expense.payerId,
                memberIds: memberIds,
                isDonation: expense.isDonation,
              );

        for (final split in splitMembers) {
          balances[split.userId] = (balances[split.userId] ?? 0) - split.amount;
        }
      }
    }

    // Round balances to avoid floating point noise
    final roundedBalances = balances.map(
      (key, value) => MapEntry(key, _round(value)),
    );

    // Simplify debts using greedy algorithm
    final settlements = _simplifyDebts(roundedBalances);

    return BalanceLedger(
      netBalances: roundedBalances,
      settlements: settlements,
      totalExpenses: _round(totalExpenses),
    );
  }

  /// Greedy debt simplification.
  /// Matches largest creditor with largest debtor iteratively.
  static List<Settlement> _simplifyDebts(Map<String, double> balances) {
    final settlements = <Settlement>[];

    // Split into creditors (positive) and debtors (negative)
    final creditors = <String, double>{};
    final debtors = <String, double>{};

    for (final entry in balances.entries) {
      if (entry.value > 0.01) {
        creditors[entry.key] = entry.value;
      } else if (entry.value < -0.01) {
        debtors[entry.key] = -entry.value; // store as positive
      }
    }

    // Greedy: match largest creditor with largest debtor
    while (creditors.isNotEmpty && debtors.isNotEmpty) {
      final topCreditor = creditors.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      final topDebtor = debtors.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );

      final amount = min(topCreditor.value, topDebtor.value);

      settlements.add(
        Settlement(
          fromUserId: topDebtor.key,
          toUserId: topCreditor.key,
          amount: _round(amount),
        ),
      );

      // Update remaining balances
      creditors[topCreditor.key] = topCreditor.value - amount;
      debtors[topDebtor.key] = topDebtor.value - amount;

      // Remove if settled
      if (creditors[topCreditor.key]! < 0.01) {
        creditors.remove(topCreditor.key);
      }
      if (debtors[topDebtor.key]! < 0.01) {
        debtors.remove(topDebtor.key);
      }
    }

    return settlements;
  }

  static double _round(double value) => (value * 100).roundToDouble() / 100;
}

/// A computed transfer needed to settle debts.
/// NOT persisted — exists only in memory.
class Settlement {
  const Settlement({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  final String fromUserId;
  final String toUserId;
  final double amount;
}
