import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';

/// The Tasks screen's search, filters, sort and grouping for one event.
/// Kept outside the screen so the list keeps them when choosing a task
/// opens it beside the list, which builds the list again on the task's
/// route (Spec #186 Req 23).
class TasksFilterController extends Notifier<TasksFilter> {
  TasksFilterController(this.eventId);

  final String eventId;

  /// Where the list was scrolled to, so it opens there again. Not state:
  /// scrolling never rebuilds anything.
  double scrollOffset = 0;

  @override
  TasksFilter build() => const TasksFilter();

  void set(TasksFilter filter) => state = filter;
}

/// The Tasks filter for one event, kept while any Tasks list shows it.
final tasksFilterProvider = NotifierProvider.autoDispose
    .family<TasksFilterController, TasksFilter, String>(
      TasksFilterController.new,
    );
