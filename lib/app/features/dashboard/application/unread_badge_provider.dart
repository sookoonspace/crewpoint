import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_assigned_tasks_provider.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// Per-tab + total unread counts surfaced as bottom-nav badges.
///
/// Each count maps to one user-facing concept:
///  - [tasks]  — incomplete tasks assigned to me (status != done)
///  - [chat]   — number of events with at least one unread message
///  - [budget] — number of open debt rows where I owe someone
///
/// [total] sums the three; [hasAny] is the cheap "anything to nudge about?"
/// check.
class UnreadBadgeCounts {
  const UnreadBadgeCounts({this.tasks = 0, this.chat = 0, this.budget = 0});

  final int tasks;
  final int chat;
  final int budget;

  int get total => tasks + chat + budget;
  bool get hasAny => total > 0;
}

/// Aggregates the three existing cross-event streams into a single
/// [UnreadBadgeCounts] value used by the bottom-nav shell.
///
/// **Loading / error policy:** a source in `loading` or `error` state
/// contributes 0 to its slot. Badges are non-critical UX — gating the
/// entire shell on every upstream resolving would block the first frame
/// for a value the user can recompute by looking at the tab itself.
/// Errors are still surfaced via the underlying providers' own AsyncValue
/// (visible to anyone reading them directly), so this is suppression for
/// the badge rendering only.
final unreadBadgeProvider = Provider.family<UnreadBadgeCounts, String>((
  ref,
  uid,
) {
  final tasksAsync = ref.watch(myAssignedTasksProvider(uid));
  final inboxAsync = ref.watch(globalInboxProvider(uid));
  final ledgerAsync = ref.watch(globalBalanceLedgerProvider(uid));

  final tasksCount = tasksAsync.maybeWhen(
    data: (rows) => rows.where((r) => r.task.status != TaskStatus.done).length,
    orElse: () => 0,
  );

  final chatCount = inboxAsync.maybeWhen(
    data: (rows) => rows.where((r) => r.unreadCount > 0).length,
    orElse: () => 0,
  );

  final budgetCount = ledgerAsync.maybeWhen(
    data: (ledger) => ledger.debts.length,
    orElse: () => 0,
  );

  return UnreadBadgeCounts(
    tasks: tasksCount,
    chat: chatCount,
    budget: budgetCount,
  );
});
