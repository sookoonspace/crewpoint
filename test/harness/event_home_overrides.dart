import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:crewpoint_app/app/features/tasks/application/event_task_counts_provider.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:flutter_riverpod/misc.dart';

/// What the Event home reads beyond the event itself (#199): its tasks,
/// sessions and spending. Screen tests without a database or Firestore
/// pass these, empty unless given, so no real mirror starts.
List<Override> eventHomeOverrides({
  List<TaskModel> tasks = const [],
  List<SessionModel> sessions = const [],
  List<ExpenseModel>? expenses = const [],
}) => [
  taskListProvider.overrideWith((ref, _) => Stream.value(tasks)),
  sessionListProvider.overrideWith((ref, _) => Stream.value(sessions)),
  eventTaskCountsProvider.overrideWith(
    (ref, _) => Stream.value((
      todo: tasks.where((t) => t.status == TaskStatus.todo).length,
      doing: tasks.where((t) => t.status == TaskStatus.inProgress).length,
      done: tasks.where((t) => t.status == TaskStatus.done).length,
    )),
  ),
  if (expenses != null)
    expenseListProvider.overrideWith((ref, _) => Stream.value(expenses)),
];
