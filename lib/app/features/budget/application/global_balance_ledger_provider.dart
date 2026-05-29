import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// One row in the cross-event debt breakdown. `amount` is always positive
/// (the user owes `counterpartyUid` this much in `event`'s currency).
class DebtRow {
  const DebtRow({
    required this.counterpartyUid,
    required this.event,
    required this.amount,
    required this.currency,
  });

  final String counterpartyUid;
  final EventModel event;
  final double amount;
  final String currency;
}

/// One row in the cross-event chronological recent expenses feed.
class RecentExpenseRow {
  const RecentExpenseRow({required this.expense, required this.event});

  final ExpenseModel expense;
  final EventModel event;
}

/// Aggregated cross-event balance state powering the Budget tab. Sums
/// are in the user's default display currency (V1: USD); see the
/// multi-currency disclaimer in the spec for the trade-off.
class LedgerSummary {
  const LedgerSummary({
    required this.totalOwedToYou,
    required this.totalYouOwe,
    required this.debts,
    required this.recentExpenses,
  });

  const LedgerSummary.empty()
    : totalOwedToYou = 0,
      totalYouOwe = 0,
      debts = const <DebtRow>[],
      recentExpenses = const <RecentExpenseRow>[];

  final double totalOwedToYou;
  final double totalYouOwe;
  final List<DebtRow> debts;
  final List<RecentExpenseRow> recentExpenses;
}

const _kRecentExpensesCap = 20;

/// Cross-event Budget ledger. Composes `dashboardEventsProvider` +
/// per-event `expenseListProvider(eventId)`; runs the existing
/// `BalanceLedger.calculate(...)` per event; folds the settlements into
/// totals + per-(counterparty, event) debt rows; flattens all expenses
/// (capped at 20) into the recent feed.
///
/// Archived events ARE included — debts survive trip closure (spec req 17).
final globalBalanceLedgerProvider =
    Provider.family<AsyncValue<LedgerSummary>, String>((ref, uid) {
      final eventsAsync = ref.watch(dashboardEventsProvider);
      final events = eventsAsync.value;
      if (events == null) {
        return switch (eventsAsync) {
          AsyncError(:final error, :final stackTrace) => AsyncError(
            error,
            stackTrace,
          ),
          _ => const AsyncLoading(),
        };
      }

      if (events.isEmpty) {
        // Don't subscribe any per-event family entry when the user has
        // zero events.
        return const AsyncData(LedgerSummary.empty());
      }

      var totalOwedToYou = 0.0;
      var totalYouOwe = 0.0;
      final debts = <DebtRow>[];
      final allExpenses = <RecentExpenseRow>[];

      for (final event in events) {
        final expensesAsync = ref.watch(expenseListProvider(event.id));
        final expenses = expensesAsync.value;
        if (expenses == null) {
          return switch (expensesAsync) {
            AsyncError(:final error, :final stackTrace) => AsyncError(
              error,
              stackTrace,
            ),
            _ => const AsyncLoading(),
          };
        }

        // Accumulate the chronological feed (cap applied after all
        // events fold).
        for (final exp in expenses) {
          allExpenses.add(RecentExpenseRow(expense: exp, event: event));
        }

        if (expenses.isEmpty) continue;

        final ledger = BalanceLedger.calculate(
          expenses: expenses,
          memberIds: event.memberIds,
        );
        for (final settlement in ledger.settlements) {
          // Drop near-zero rows (round to cents, $0.00 means nothing
          // owed once display formatting kicks in).
          if (settlement.amount.toStringAsFixed(2) == '0.00') continue;

          if (settlement.toUserId == uid) {
            totalOwedToYou += settlement.amount;
          } else if (settlement.fromUserId == uid) {
            totalYouOwe += settlement.amount;
            debts.add(
              DebtRow(
                counterpartyUid: settlement.toUserId,
                event: event,
                amount: settlement.amount,
                currency: event.currency,
              ),
            );
          }
          // Settlements between two other users are ignored — only the
          // current user's perspective matters here.
        }
      }

      debts.sort((a, b) => b.amount.compareTo(a.amount));
      allExpenses.sort(
        (a, b) =>
            (b.expense.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.expense.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
      );
      final recent = allExpenses.take(_kRecentExpensesCap).toList();

      return AsyncData(
        LedgerSummary(
          totalOwedToYou: _round(totalOwedToYou),
          totalYouOwe: _round(totalYouOwe),
          debts: debts,
          recentExpenses: recent,
        ),
      );
    });

double _round(double value) => (value * 100).roundToDouble() / 100;
