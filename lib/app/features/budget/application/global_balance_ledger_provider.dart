import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// One row in the cross-event debt breakdown. `amount` is always positive
/// (the user owes `counterpartyUid` this much in `event`'s currency).
class DebtRow {
  const DebtRow({
    required this.counterpartyUid,
    required this.counterpartyName,
    required this.event,
    required this.amount,
    required this.currency,
  });

  final String counterpartyUid;

  /// Resolved display name for [counterpartyUid] (via the event's user
  /// roster). Falls back to `kRemovedMemberPlaceholder` when the user is
  /// no longer in the event roster.
  final String counterpartyName;
  final EventModel event;
  final double amount;
  final String currency;
}

/// One row in the cross-event chronological recent expenses feed.
class RecentExpenseRow {
  const RecentExpenseRow({
    required this.expense,
    required this.event,
    required this.payerName,
  });

  final ExpenseModel expense;
  final EventModel event;

  /// Resolved display name for `expense.payerId`. Placeholder when the
  /// payer is no longer in the event roster.
  final String payerName;
}

/// Aggregated cross-event balance state powering the Budget tab. Sums
/// are in the user's default display currency (V1: USD); see the
/// multi-currency disclaimer in the spec for the trade-off.
/// What the user is owed and owes in one currency.
class CurrencyTotals {
  const CurrencyTotals({required this.owedToYou, required this.youOwe});

  final double owedToYou;
  final double youOwe;
}

class LedgerSummary {
  const LedgerSummary({
    required this.totalsByCurrency,
    required this.debts,
    required this.recentExpenses,
  });

  const LedgerSummary.empty()
    : totalsByCurrency = const {},
      debts = const <DebtRow>[],
      recentExpenses = const <RecentExpenseRow>[];

  /// Kept apart, because amounts in different currencies cannot be added.
  final Map<String, CurrencyTotals> totalsByCurrency;
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

      final owedToYou = <String, double>{};
      final youOwe = <String, double>{};
      final debts = <DebtRow>[];
      final allExpenses = <RecentExpenseRow>[];

      for (final event in events.where((e) => e.isModuleOn('budget'))) {
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

        // Fetch the people in this event so debt + recent-expense rows can
        // render display names instead of raw UIDs.
        final rosterAsync = ref.watch(usersByIdProvider(event.id));
        final roster = rosterAsync.value;
        if (roster == null) {
          return switch (rosterAsync) {
            AsyncError(:final error, :final stackTrace) => AsyncError(
              error,
              stackTrace,
            ),
            _ => const AsyncLoading(),
          };
        }

        // displayName → email fold, matching event_chat_page.dart:107-113.
        final memberNames = <String, String>{};
        for (final entry in roster.entries) {
          final name = entry.value.displayName;
          if (name != null && name.isNotEmpty) {
            memberNames[entry.key] = name;
          } else if (entry.value.email.isNotEmpty) {
            memberNames[entry.key] = entry.value.email;
          }
        }

        // Accumulate the chronological feed (cap applied after all
        // events fold).
        for (final exp in expenses) {
          allExpenses.add(
            RecentExpenseRow(
              expense: exp,
              event: event,
              payerName: resolveMemberName(
                uid: exp.payerId,
                memberNames: memberNames,
              ),
            ),
          );
        }

        // Someone who may not read every expense gets their transfers from
        // the server, worked out from all of them (Req 38c, 38f). Debts can
        // exist even when none of the expenses are in view.
        final List<Settlement> settlements;
        if (event.readsAllExpenses(uid)) {
          if (expenses.isEmpty) continue;
          settlements = BalanceLedger.calculate(
            expenses: expenses,
            memberIds: event.memberIds,
          ).settlements;
        } else {
          final mine = ref.watch(myBalanceProvider(event.id));
          if (mine.isLoading && !mine.hasValue) return const AsyncLoading();
          // Offline or refused: leave this event out rather than the tab.
          settlements = mine.value?.transfers ?? const [];
        }
        for (final settlement in settlements) {
          // Drop near-zero rows (round to cents, $0.00 means nothing
          // owed once display formatting kicks in).
          if (settlement.amount.toStringAsFixed(2) == '0.00') continue;

          if (settlement.toUserId == uid) {
            owedToYou.update(
              event.currency,
              (sum) => sum + settlement.amount,
              ifAbsent: () => settlement.amount,
            );
          } else if (settlement.fromUserId == uid) {
            youOwe.update(
              event.currency,
              (sum) => sum + settlement.amount,
              ifAbsent: () => settlement.amount,
            );
            debts.add(
              DebtRow(
                counterpartyUid: settlement.toUserId,
                counterpartyName: resolveMemberName(
                  uid: settlement.toUserId,
                  memberNames: memberNames,
                ),
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
          totalsByCurrency: {
            for (final currency in {...owedToYou.keys, ...youOwe.keys})
              currency: CurrencyTotals(
                owedToYou: _round(owedToYou[currency] ?? 0),
                youOwe: _round(youOwe[currency] ?? 0),
              ),
          },
          debts: debts,
          recentExpenses: recent,
        ),
      );
    });

double _round(double value) => (value * 100).roundToDouble() / 100;
