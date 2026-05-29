import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/widgets/event_tile.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/event_task_counts_provider.dart';

/// Dashboard event row. Thin Riverpod adapter — watches
/// `eventTaskCountsProvider(event.id)` and forwards counts to the pure
/// `EventTile`. The StreamProvider rebuilds this widget whenever the Drift
/// `tasks` table mutates, so the ring stays current without manual
/// invalidation.
class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event, this.onTap});

  final EventModel event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(eventTaskCountsProvider(event.id));
    return countsAsync.when(
      data: (counts) => EventTile(
        event: event,
        todo: counts.todo,
        doing: counts.doing,
        done: counts.done,
        onTap: onTap,
      ),
      loading: () =>
          EventTile(event: event, todo: 0, doing: 0, done: 0, onTap: onTap),
      error: (error, stack) {
        developer.log(
          'eventTaskCountsProvider failed for event ${event.id}',
          name: 'dashboard.eventCard',
          error: error,
          stackTrace: stack,
        );
        return EventTile(
          event: event,
          todo: 0,
          doing: 0,
          done: 0,
          onTap: onTap,
        );
      },
    );
  }
}
