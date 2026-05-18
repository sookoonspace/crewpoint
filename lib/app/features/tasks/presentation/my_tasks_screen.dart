import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_assets.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/empty_state_placeholder.dart';
import 'package:crewpoint_app/app/core/widgets/screen_header.dart';
import 'package:crewpoint_app/app/core/widgets/section_label.dart';
import 'package:crewpoint_app/app/core/widgets/segmented_filter_bar.dart';
import 'package:crewpoint_app/app/core/widgets/skeletons.dart';
import 'package:crewpoint_app/app/core/widgets/status_badge.dart';
import 'package:crewpoint_app/app/core/widgets/task_progress_summary.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/event_type_emoji.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_assigned_tasks_provider.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_tile.dart';

/// Navigation seam for opening a row's task-detail screen. Tests inject a
/// capturing callback; production falls through to `context.push(...)`.
typedef OpenTaskCallback =
    void Function(BuildContext context, MyAssignedTaskRow row);

/// Cross-event "My Tasks" tab. Shows tasks assigned to the current user
/// across every event they belong to. Filtered by [MyTasksFilter] (segment
/// + overdue toggle).
class MyTasksScreen extends ConsumerStatefulWidget {
  const MyTasksScreen({super.key, this.onOpenTask, this.onOpenDashboard});

  final OpenTaskCallback? onOpenTask;

  /// Test seam for the empty-state CTA. Production leaves this null and the
  /// CTA fires `context.go(AppRoutes.dashboard)`.
  final VoidCallback? onOpenDashboard;

  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen> {
  MyTasksFilter _filter = const MyTasksFilter();

  ({int todo, int doing, int done}) _summarize(List<MyAssignedTaskRow> rows) {
    var todo = 0;
    var doing = 0;
    var done = 0;
    for (final row in rows) {
      switch (row.task.status) {
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

  int _overdueCount(List<MyAssignedTaskRow> rows) {
    return rows
        .where(
          (r) =>
              r.task.status != TaskStatus.done &&
              r.task.dueDate != null &&
              r.task.dueDate!.isBefore(DateTime.now()),
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.tasks;
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: uid == null
            ? EmptyStatePlaceholder(title: s.signInRequiredTitle)
            : ref
                  .watch(myAssignedTasksProvider(uid))
                  .when(
                    loading: () => const MyTasksSkeleton(),
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
                        lottieAsset: AppAssets.lottieError,
                      );
                    },
                    data: (allRows) {
                      // Adaptive empty state when there are no tasks at all.
                      if (allRows.isEmpty) {
                        return _MyTasksEmptyState(
                          strings: s,
                          onOpenDashboard: widget.onOpenDashboard,
                        );
                      }
                      return _MyTasksBody(
                        allRows: allRows,
                        filter: _filter,
                        onFilterChanged: (next) =>
                            setState(() => _filter = next),
                        summarize: _summarize,
                        overdueCount: _overdueCount(allRows),
                        onOpenTask: widget.onOpenTask,
                      );
                    },
                  ),
      ),
    );
  }
}

class _MyTasksBody extends StatelessWidget {
  const _MyTasksBody({
    required this.allRows,
    required this.filter,
    required this.onFilterChanged,
    required this.summarize,
    required this.overdueCount,
    this.onOpenTask,
  });

  final List<MyAssignedTaskRow> allRows;
  final MyTasksFilter filter;
  final ValueChanged<MyTasksFilter> onFilterChanged;
  final ({int todo, int doing, int done}) Function(List<MyAssignedTaskRow>)
  summarize;
  final int overdueCount;
  final OpenTaskCallback? onOpenTask;

  @override
  Widget build(BuildContext context) {
    final filtered = filter.apply(allRows);
    final summary = summarize(filtered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader(key: Key('myTasks.header'), title: 'My Tasks'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: KeyedSubtree(
            key: const Key('tasks.header.summary'),
            child: TaskProgressSummary(
              todo: summary.todo,
              doing: summary.doing,
              done: summary.done,
            ),
          ),
        ),
        SegmentedFilterBar<MyTasksSegment>(
          key: const Key('myTasks.filter'),
          selected: filter.segment,
          segments: const [
            SegmentedFilterSegment(
              value: MyTasksSegment.all,
              label: 'All',
              keyValue: Key('myTasks.filter.all'),
            ),
            SegmentedFilterSegment(
              value: MyTasksSegment.todo,
              label: 'To Do',
              keyValue: Key('myTasks.filter.todo'),
            ),
            SegmentedFilterSegment(
              value: MyTasksSegment.doing,
              label: 'Doing',
              keyValue: Key('myTasks.filter.doing'),
            ),
            SegmentedFilterSegment(
              value: MyTasksSegment.done,
              label: 'Done',
              keyValue: Key('myTasks.filter.done'),
            ),
          ],
          onChanged: (next) => onFilterChanged(filter.copyWith(segment: next)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              InkWell(
                key: const Key('myTasks.filter.overdueToggle'),
                borderRadius: BorderRadius.circular(999),
                onTap: () =>
                    onFilterChanged(filter.copyWith(overdue: !filter.overdue)),
                child: Opacity(
                  opacity: filter.overdue ? 1.0 : 0.55,
                  child: StatusBadge.urgent(
                    label: 'Overdue',
                    count: overdueCount,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ContentMaxWidth(
            maxWidth: 720,
            child: filtered.isEmpty
                ? _NoMatchesEmptyState(filter: filter)
                : _MyTasksList(rows: filtered, onOpenTask: onOpenTask),
          ),
        ),
      ],
    );
  }
}

/// Grouped list of assigned tasks. One `SectionLabel` per distinct event,
/// then a `TaskTile` per row.
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
        groups.add(
          _EventGroup(
            eventId: row.event.id,
            title: row.event.title,
            emoji: emojiForEventType(row.event.eventType),
          ),
        );
      }
      groups.last.rows.add(row);
    }

    return ListView(
      key: const Key('myTasks.list'),
      padding: EdgeInsets.symmetric(
        horizontal: Breakpoints.screenHorizontalPadding(context),
        vertical: AppSpacing.lg,
      ),
      children: [
        for (final group in groups) ...[
          Padding(
            key: Key('myTasks.groupHeader.${group.eventId}'),
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            child: SectionLabel('${group.emoji}  ${group.title}'),
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
    );
  }
}

class _EventGroup {
  _EventGroup({
    required this.eventId,
    required this.title,
    required this.emoji,
  });
  final String eventId;
  final String title;
  final String emoji;
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

/// Shown when the user has tasks but the current filter excludes all of
/// them. Lighter weight than the full empty state — just a centered note.
class _NoMatchesEmptyState extends StatelessWidget {
  const _NoMatchesEmptyState({required this.filter});

  final MyTasksFilter filter;

  @override
  Widget build(BuildContext context) {
    final segmentLabel = switch (filter.segment) {
      MyTasksSegment.all => 'this filter',
      MyTasksSegment.todo => '"To Do"',
      MyTasksSegment.doing => '"Doing"',
      MyTasksSegment.done => '"Done"',
    };
    final message = filter.overdue
        ? 'No overdue tasks match $segmentLabel.'
        : 'No tasks match $segmentLabel yet.';
    return Center(
      key: const Key('myTasks.noMatches'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.darkGrey),
        ),
      ),
    );
  }
}
