import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/core/providers.dart';

/// Reactive per-event task status counts, sourced from the local Drift
/// `tasks` table via `TasksDao.watchCountsByEventId`. Powers the Dashboard
/// `EventTile` progress ring.
///
/// Family key: event id.
/// Emits whenever the underlying `tasks` table mutates locally — including
/// when `TaskRepository` mirrors a Firestore change into Drift — so the ring
/// stays current without manual invalidation. No Firestore subscription is
/// opened by this provider itself.
final eventTaskCountsProvider =
    StreamProvider.family<({int todo, int doing, int done}), String>((
      ref,
      eventId,
    ) {
      final dao = TasksDao(ref.watch(databaseProvider));
      return dao.watchCountsByEventId(eventId);
    });
