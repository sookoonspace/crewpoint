import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/empty_state_placeholder.dart';
import 'package:crewpoint_app/app/core/widgets/loading_animation.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_assigned_tasks_provider.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_tile.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/tasks_group_header.dart';

/// Navigation seam for opening a row's task-detail screen. Tests inject a
/// capturing callback; production falls through to `context.push(...)`.
typedef OpenTaskCallback =
    void Function(BuildContext context, MyAssignedTaskRow row);

/// Cross-event "My Tasks" tab. Shows tasks assigned to the current user
/// across every event they belong to. Empty / loading / error states all
/// route through `EmptyStatePlaceholder` for brand consistency.
class MyTasksScreen extends ConsumerWidget {
  const MyTasksScreen({super.key, this.onOpenTask, this.onOpenDashboard});

  /// Optional override of the per-tile navigation. Production code leaves
  /// this null and lets `context.push('/dashboard/event/<id>/tasks/<id>')`
  /// fire from inside the screen — but widget tests inject a fake to
  /// capture the row without a real router in scope.
  final OpenTaskCallback? onOpenTask;

  /// Optional override of the empty-state CTA. Production leaves this null
  /// and the CTA fires `context.go(AppRoutes.dashboard)`. Robot journey
  /// tests inject a capturing callback because they run without a real
  /// `GoRouter` ancestor.
  final VoidCallback? onOpenDashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings.tasks;
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(s.myTasksAppBarTitle),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      // `uid` is read defensively so the family provider is never invoked
      // with a null arg (spec req 8 + 21).
      body: uid == null
          ? EmptyStatePlaceholder(title: s.signInRequiredTitle)
          : ref
                .watch(myAssignedTasksProvider(uid))
                .when(
                  loading: () => const Center(child: LoadingAnimation()),
                  error: (error, stackTrace) {
                    developer.log(
                      'Failed to load assigned tasks',
                      name: 'tasks.myTasks',
                      error: error,
                      stackTrace: stackTrace,
                    );
                    return EmptyStatePlaceholder(
                      title: 'Could not load tasks',
                      subtitle: error.toString(),
                      lottieAsset: 'assets/animations/error.json',
                    );
                  },
                  data: (rows) {
                    if (rows.isEmpty) {
                      return _MyTasksEmptyState(
                        strings: s,
                        onOpenDashboard: onOpenDashboard,
                      );
                    }
                    return _MyTasksList(rows: rows, onOpenTask: onOpenTask);
                  },
                ),
    );
  }
}

/// Grouped list of assigned tasks. One `TasksGroupHeader` per distinct
/// event, then a `TaskTile` per row. Tap → navigates to the event-scoped
/// task detail (or fires the test seam).
class _MyTasksList extends StatelessWidget {
  const _MyTasksList({required this.rows, this.onOpenTask});

  final List<MyAssignedTaskRow> rows;
  final OpenTaskCallback? onOpenTask;

  @override
  Widget build(BuildContext context) {
    // Group consecutive rows by event id, preserving the source order.
    final groups = <_EventGroup>[];
    for (final row in rows) {
      if (groups.isEmpty || groups.last.eventId != row.event.id) {
        groups.add(_EventGroup(eventId: row.event.id, title: row.event.title));
      }
      groups.last.rows.add(row);
    }

    return ContentMaxWidth(
      maxWidth: 720,
      child: ListView(
        key: const Key('myTasks.list'),
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.lg,
        ),
        children: [
          for (final group in groups) ...[
            TasksGroupHeader(
              key: Key('myTasks.groupHeader.${group.eventId}'),
              label: group.title,
            ),
            for (final row in group.rows)
              TaskTile(
                task: row.task,
                canChangeStatus: false,
                currencyCode: row.event.currency,
                onTap: () {
                  final cb = onOpenTask;
                  if (cb != null) {
                    cb(context, row);
                  } else {
                    context.push(
                      '/dashboard/event/${row.event.id}/tasks/${row.task.id}',
                    );
                  }
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _EventGroup {
  _EventGroup({required this.eventId, required this.title});
  final String eventId;
  final String title;
  final List<MyAssignedTaskRow> rows = <MyAssignedTaskRow>[];
}

/// Adaptive empty-state copy + CTA per spec req 23: when the user has
/// zero events the dashboard CTA prompts them to *create* one;
/// otherwise it prompts them to *open* one.
class _MyTasksEmptyState extends ConsumerWidget {
  const _MyTasksEmptyState({required this.strings, this.onOpenDashboard});

  final TasksStrings strings;
  final VoidCallback? onOpenDashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasEvents = ref
        .watch(dashboardEventsProvider)
        .maybeWhen(data: (events) => events.isNotEmpty, orElse: () => false);

    return EmptyStatePlaceholder(
      title: strings.myTasksEmptyTitle,
      subtitle: hasEvents
          ? strings.myTasksEmptySubtitle
          : strings.myTasksEmptySubtitleNoEvents,
      ctaLabel: hasEvents
          ? strings.openDashboardCta
          : strings.createFromDashboardCta,
      onCta: () {
        final cb = onOpenDashboard;
        if (cb != null) {
          cb();
        } else {
          context.go(AppRoutes.dashboard);
        }
      },
    );
  }
}
