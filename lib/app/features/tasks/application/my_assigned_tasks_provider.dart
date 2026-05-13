import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// One row of the cross-event "My Tasks" list — a task plus the event it
/// belongs to (so callers have everything they need to render without a
/// second lookup).
class MyAssignedTaskRow {
  const MyAssignedTaskRow({required this.task, required this.event});

  final TaskModel task;
  final EventModel event;
}

/// Cross-event aggregate of tasks assigned to the given uid. Composes
/// existing providers — no new repo or DAO surface.
///
/// `ref.watch(dashboardEventsProvider)` → for each event
/// `ref.watch(taskListProvider(event.id))` → filter by `assigneeId == uid`
/// → flatten. Any input `loading` → `loading()`; any input `error` →
/// `error(...)`.
final myAssignedTasksProvider =
    Provider.family<AsyncValue<List<MyAssignedTaskRow>>, String>((ref, uid) {
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

      final rows = <MyAssignedTaskRow>[];
      for (final event in events) {
        final tasksAsync = ref.watch(taskListProvider(event.id));
        final tasks = tasksAsync.value;
        if (tasks == null) {
          return switch (tasksAsync) {
            AsyncError(:final error, :final stackTrace) => AsyncError(
              error,
              stackTrace,
            ),
            _ => const AsyncLoading(),
          };
        }
        for (final task in tasks) {
          if (task.assigneeId == uid) {
            rows.add(MyAssignedTaskRow(task: task, event: event));
          }
        }
      }
      return AsyncData(rows);
    });
