/// Sizes past which money screens stop including everyone in an event
/// (Req 43a), so a large event stays quick and never reads every name.
library;

import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

/// Up to this many members, an equal split includes everyone by default.
const largeEventMembers = 50;

/// How many of the largest balances a large event's balance card shows,
/// besides your own.
const largeEventTopBalances = 20;

/// Whether an equal split must name who shares it, instead of defaulting to
/// everyone.
bool splitNeedsChoosing(int memberCount) => memberCount > largeEventMembers;

/// Whose balances the balance card shows: everyone up to
/// [largeEventMembers] members; past that, [me] and the
/// [largeEventTopBalances] largest balances owed or owing, leaving out
/// anyone settled.
Set<String> shownBalanceUids(
  Map<String, double> balances, {
  required String me,
  required int memberCount,
}) {
  if (memberCount <= largeEventMembers) return balances.keys.toSet();
  final open =
      balances.entries.where((e) => e.value.abs() >= 0.005).toList()
        ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
  return {
    for (final e in open.take(largeEventTopBalances)) e.key,
    if (balances.containsKey(me)) me,
  };
}

/// Which transfers Settle Up lists: all of them up to [largeEventMembers]
/// members; past that, every one you pay or receive and the
/// [largeEventTopBalances] largest others, largest first.
List<Settlement> shownSettlements(
  List<Settlement> settlements, {
  required String me,
  required int memberCount,
}) {
  if (memberCount <= largeEventMembers) return settlements;
  bool mine(Settlement s) => s.fromUserId == me || s.toUserId == me;
  final others = settlements.where((s) => !mine(s)).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return [
    ...others.take(largeEventTopBalances),
    ...settlements.where(mine),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
}

/// Whose names the budget page needs: the payers, and the people in the
/// balances and transfers it shows. Nobody else is read (Req 43a).
Set<String> budgetNameUids({
  required List<ExpenseModel> expenses,
  required BalanceLedger ledger,
  required String me,
  required int memberCount,
}) => {
  for (final e in expenses) e.payerId,
  ...shownBalanceUids(ledger.netBalances, me: me, memberCount: memberCount),
  for (final s in shownSettlements(
    ledger.settlements,
    me: me,
    memberCount: memberCount,
  )) ...[s.fromUserId, s.toUserId],
};
