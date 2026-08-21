import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// Reactive per-event task status counts. Powers the Dashboard `EventTile`
/// progress ring.
///
/// Family key: event id.
///
/// **Native** reads the local Drift `tasks` table via
/// `TasksDao.watchCountsByEventId`, emitting whenever that table mutates —
/// including when `TaskRepository` mirrors a Firestore change into Drift — so
/// the ring stays current without manual invalidation.
///
/// **Web** forks to the raw Firestore stream, the same fork
/// `TaskRepository.watchTasksByEventId` and `EventRepository` already make.
/// Drift on web is Wasm/in-memory and nothing mirrors into it, so the DAO
/// counts never observed server-side writes at all. The `done` transition is
/// the visible case: `TaskRepository.updateStatus` routes it through the
/// `markTaskComplete` callable rather than a client write, so on web the badge
/// kept serving pre-completion counts and survived a reload.
final eventTaskCountsProvider =
    StreamProvider.family<({int todo, int doing, int done}), String>((
      ref,
      eventId,
    ) {
      if (kIsWeb) {
        final repo = ref.watch(taskRepositoryProvider);
        return repo.watchTasksByEventId(eventId).map(_countByStatus);
      }
      final dao = TasksDao(ref.watch(databaseProvider));
      return dao.watchCountsByEventId(eventId);
    });

/// Mirrors `TasksDao.watchCountsByEventId`'s tally so both platforms report
/// counts identically.
({int todo, int doing, int done}) _countByStatus(List<TaskModel> tasks) {
  var todo = 0;
  var doing = 0;
  var done = 0;
  for (final task in tasks) {
    switch (task.status) {
      case TaskStatus.todo:
        todo++;
      case TaskStatus.inProgress:
        doing++;
      case TaskStatus.done:
        done++;
    }
  }
  return (todo: todo, doing: doing, done: done);
}
