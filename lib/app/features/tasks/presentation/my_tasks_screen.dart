import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_assigned_tasks_provider.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_tile.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/tasks_group_header.dart';

/// Navigation seam for opening a row's task-detail screen. Tests inject a
/// capturing callback; production falls through to `context.push(...)`.
typedef OpenTaskCallback =
    void Function(BuildContext context, MyAssignedTaskRow row);

/// The "My tasks" tab (Spec #186): tasks assigned to the viewer across
/// every event they belong to, with progress, status filters and an
/// Overdue filter, grouped by event.
class MyTasksScreen extends ConsumerStatefulWidget {
  const MyTasksScreen({super.key, this.onOpenTask, this.onOpenDashboard});

  final OpenTaskCallback? onOpenTask;

  /// Test seam for the empty-state action. Production leaves this null and
  /// the action goes to `AppRoutes.dashboard`.
  final VoidCallback? onOpenDashboard;

  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen> {
  MyTasksFilter _filter = const MyTasksFilter();

  @override
  Widget build(BuildContext context) {
    final s = context.strings.tasks;
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: context.cp.colors.background,
      appBar: CpTopBar(title: s.myTasksAppBarTitle),
      body: uid == null
          ? CpEmptyState(icon: CpIcons.lock, title: s.signInRequiredTitle)
          : ref
                .watch(myAssignedTasksProvider(uid))
                .when(
                  loading: () => CpLoadingState.rows(
                    key: const Key('myTasks.loading'),
                    semanticLabel: s.myTasksAppBarTitle,
                  ),
                  error: (error, stackTrace) {
                    developer.log(
                      'Failed to load assigned tasks',
                      name: 'tasks.myTasks',
                      error: error,
                      stackTrace: stackTrace,
                    );
                    return CpErrorState(
                      key: const Key('myTasks.error'),
                      title: s.loadFailed,
                      retryLabel: context.strings.people.retry,
                      retryKey: const Key('myTasks.retry'),
                      onRetry: () =>
                          ref.invalidate(myAssignedTasksProvider(uid)),
                    );
                  },
                  data: (allRows) {
                    // Nothing assigned at all.
                    if (allRows.isEmpty) {
                      return _MyTasksEmptyState(
                        onOpenDashboard: widget.onOpenDashboard,
                      );
                    }
                    return _MyTasksBody(
                      allRows: allRows,
                      filter: _filter,
                      onFilterChanged: (next) => setState(() => _filter = next),
                      onOpenTask: widget.onOpenTask,
                    );
                  },
                ),
    );
  }
}

class _MyTasksBody extends StatelessWidget {
  const _MyTasksBody({
    required this.allRows,
    required this.filter,
    required this.onFilterChanged,
    this.onOpenTask,
  });

  final List<MyAssignedTaskRow> allRows;
  final MyTasksFilter filter;
  final ValueChanged<MyTasksFilter> onFilterChanged;
  final OpenTaskCallback? onOpenTask;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.tasks;
    final now = clock.now();
    final filtered = filter.apply(allRows);
    final progress = taskProgress([for (final r in filtered) r.task], now);
    final overdue = taskProgress([
      for (final r in allRows) r.task,
    ], now).overdue;
    final headline = s.doneOf(progress.done, progress.total);

    Widget segment(MyTasksSegment value, String name, String label) =>
        CpFilterChip(
          key: Key('myTasks.filter.$name'),
          label: label,
          selected: filter.segment == value,
          onTap: () => onFilterChanged(filter.copyWith(segment: value)),
        );

    return ContentMaxWidth(
      maxWidth: cp.sizes.phoneColumn,
      child: ListView(
        key: const Key('myTasks.list'),
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.sm,
          cp.space.lg,
          cp.space.xxl,
        ),
        children: [
          CpCard(
            key: const Key('tasks.header.summary'),
            padding: EdgeInsets.all(cp.space.lg),
            child: Row(
              spacing: cp.space.lg,
              children: [
                CpProgressRing(
                  value: progress.total == 0
                      ? 0
                      : progress.done / progress.total,
                  semanticLabel: headline,
                  size: cp.sizes.ringLg,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: cp.space.xs / 2,
                    children: [
                      Text(
                        headline,
                        style: cp.type.titleMedium.copyWith(
                          color: cp.colors.text,
                        ),
                      ),
                      Text(
                        s.progressDetail(
                          progress.overdue,
                          progress.dueThisWeek,
                        ),
                        style: cp.type.bodySmall.copyWith(
                          color: cp.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: cp.space.md),
          SingleChildScrollView(
            key: const Key('myTasks.filter'),
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: cp.space.sm,
              children: [
                segment(MyTasksSegment.all, 'all', s.filterAll),
                segment(MyTasksSegment.todo, 'todo', s.statusTodo),
                segment(MyTasksSegment.doing, 'doing', s.statusInProgress),
                segment(MyTasksSegment.done, 'done', s.statusDone),
                CpFilterChip(
                  key: const Key('myTasks.filter.overdueToggle'),
                  label: s.overdueCount(overdue),
                  selected: filter.overdue,
                  onTap: () => onFilterChanged(
                    filter.copyWith(overdue: !filter.overdue),
                  ),
                ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            Padding(
              key: const Key('myTasks.noMatches'),
              padding: EdgeInsets.only(top: cp.space.xl),
              child: CpEmptyState(
                icon: CpIcons.navTasks,
                title: s.myTasksNoMatches,
              ),
            )
          else
            ..._groups(context, filtered),
        ],
      ),
    );
  }

  /// One card per event, in the order the rows came.
  List<Widget> _groups(BuildContext context, List<MyAssignedTaskRow> rows) {
    final groups = <List<MyAssignedTaskRow>>[];
    for (final row in rows) {
      if (groups.isEmpty || groups.last.first.event.id != row.event.id) {
        groups.add([]);
      }
      groups.last.add(row);
    }
    return [
      for (final group in groups) ...[
        TasksGroupHeader(
          key: Key('myTasks.groupHeader.${group.first.event.id}'),
          label: group.first.event.title,
          count: group.length,
        ),
        CpCard(
          child: CpRowGroup(
            children: [
              for (final row in group)
                TaskTile(
                  task: row.task,
                  canChangeStatus: false,
                  currencyCode: row.event.currency,
                  showAssignee: false,
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
            ],
          ),
        ),
      ],
    ];
  }
}

/// Nothing assigned: with no events the action asks to create one,
/// otherwise to open one.
class _MyTasksEmptyState extends ConsumerWidget {
  const _MyTasksEmptyState({this.onOpenDashboard});

  final VoidCallback? onOpenDashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings.tasks;
    final hasEvents = ref
        .watch(dashboardEventsProvider)
        .maybeWhen(data: (events) => events.isNotEmpty, orElse: () => false);

    return CpEmptyState(
      key: const Key('myTasks.empty'),
      icon: CpIcons.navTasks,
      title: s.myTasksEmptyTitle,
      message: hasEvents
          ? s.myTasksEmptySubtitle
          : s.myTasksEmptySubtitleNoEvents,
      actionLabel: hasEvents ? s.openDashboardCta : s.createFromDashboardCta,
      actionKey: const Key('myTasks.empty.action'),
      onAction: () {
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
