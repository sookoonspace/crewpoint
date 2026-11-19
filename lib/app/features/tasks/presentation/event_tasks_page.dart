import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/layout/cp_list_detail.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/widgets/last_updated_note.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/crew.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter_controller.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_export_pipeline.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_repository.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/create_task_screen.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/task_list_screen.dart';

/// The event's Tasks, reading the live `taskListProvider(eventId)` and
/// saving through `taskRepositoryProvider`.
///
/// On a task's route [detail] is that task: from 840 px it shows beside
/// the list with [selectedId] chosen, and narrower it is the whole page
/// (Spec #186 Req 23).
class EventTasksPage extends ConsumerStatefulWidget {
  const EventTasksPage({
    super.key,
    required this.event,
    this.selectedId,
    this.detail,
  });

  final EventModel event;
  final String? selectedId;
  final Widget? detail;

  @override
  ConsumerState<EventTasksPage> createState() => _EventTasksPageState();
}

class _EventTasksPageState extends ConsumerState<EventTasksPage> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(
      initialScrollOffset: _filterController.scrollOffset,
    );
    _scroll.addListener(() {
      if (mounted && _scroll.hasClients) {
        _filterController.scrollOffset = _scroll.offset;
      }
    });
  }

  /// Read fresh each time, never in dispose: the provider is rebuilt when
  /// no list has watched it for a while.
  TasksFilterController get _filterController =>
      ref.read(tasksFilterProvider(widget.event.id).notifier);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String? _currentUserId() {
    final auth = ref.read(authProvider);
    return auth is Authenticated ? auth.user.uid : null;
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onCreate(
    Map<String, String> displayNames,
    List<CrewModel> crews,
  ) async {
    final uid = _currentUserId();
    if (uid == null) return;
    final failed = context.strings.tasks.createFailed;
    final created = await Navigator.of(context).push<TaskModel>(
      MaterialPageRoute(
        builder: (_) => CreateTaskScreen(
          event: widget.event,
          currentUserId: uid,
          displayNames: displayNames,
          crews: crews,
          onSubmit: (task) => Navigator.of(context).pop(task),
        ),
      ),
    );
    if (created == null) return;
    final ok = await ref.read(taskRepositoryProvider).createTask(created);
    if (!ok) _say(failed);
  }

  Future<void> _onStatusChanged(TaskModel task, TaskStatus newStatus) async {
    final failed = context.strings.tasks.statusFailed;
    final ok = await ref
        .read(taskRepositoryProvider)
        .updateStatus(
          eventId: task.eventId,
          taskId: task.id,
          newStatus: newStatus,
        );
    if (!ok) _say(failed);
  }

  Future<void> _exportPdf(
    List<TaskModel> tasks,
    Map<String, String> memberNames,
  ) async {
    final failed = context.strings.tasks.exportFailed;
    try {
      await runTaskPdfExport(
        event: widget.event,
        tasks: tasks,
        memberNames: memberNames,
        exporter: ref.read(fileExporterProvider),
      );
    } catch (_) {
      _say(failed);
    }
  }

  void _open(TaskModel task) {
    final path = '/dashboard/event/${widget.event.id}/tasks/${task.id}';
    if (CpListDetail.isSplit(context)) {
      context.go(path, extra: task);
    } else {
      context.push(path, extra: task);
    }
  }

  void _back() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    // Narrower than 840 px a task's route is the task alone.
    final detail = widget.detail;
    if (detail != null && !CpListDetail.isSplit(context)) return detail;

    final s = context.strings.tasks;
    final uid = _currentUserId();
    if (uid == null) {
      return Scaffold(
        body: CpEmptyState(icon: CpIcons.lock, title: s.signInRequiredTitle),
      );
    }

    final eventId = widget.event.id;
    final storedFilter = ref.watch(tasksFilterProvider(eventId));
    final budgets =
        ref.watch(taskBudgetsProvider(eventId)).value ??
        const <String, double>{};
    final asyncTasks = ref
        .watch(taskListProvider(eventId))
        .whenData((tasks) => withBudgets(tasks, budgets));
    final crews =
        ref.watch(eventCrewsProvider(eventId)).value ?? const <CrewModel>[];
    // A crew deleted while it is the filter stops filtering.
    final filter =
        storedFilter.crewId != null &&
            !crews.any((c) => c.id == storedFilter.crewId)
        ? storedFilter.copyWith(clearCrewId: true)
        : storedFilter;

    Widget bare(Widget body) => Scaffold(
      appBar: CpTopBar(
        title: s.tasksAppBarTitle,
        leadingKey: const Key('tasks.list.back'),
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: _back,
      ),
      body: body,
    );

    return asyncTasks.when(
      data: (tasks) {
        // Names of the people these tasks are assigned to, read one by one,
        // never the whole event (Req 43a).
        final asyncUsers = ref.watch(
          peopleByIdProvider(
            PeopleKey(eventId, [for (final task in tasks) ?task.assigneeId]),
          ),
        );
        // Prefer displayName, fall back to email when not set.
        final memberNames = asyncUsers.maybeWhen(
          data: (users) => {
            for (final entry in users.entries)
              entry.key: () {
                final name = entry.value.displayName;
                if (name != null && name.isNotEmpty) return name;
                if (entry.value.email.isNotEmpty) return entry.value.email;
                return '';
              }(),
          },
          orElse: () => <String, String>{},
        );
        // `clock.now()` keeps overdue and due windows deterministic under
        // withClock(...) in journey tests.
        final now = clock.now();
        final filtered = applyTasksFilter(
          tasks,
          filter,
          currentUserId: uid,
          now: now,
        );
        final groups = groupTasks(
          filtered,
          // With no crews, grouping by crew falls back to status.
          crews.isEmpty && filter.groupBy == TasksGroupBy.crew
              ? TasksGroupBy.status
              : filter.groupBy,
          now: now,
          assigneeNames: memberNames,
          crewNames: {for (final c in crews) c.id: c.name},
          noCrewLabel: context.strings.crews.noCrew(
            widget.event.words.one('crew'),
          ),
          labels: (
            todo: s.statusTodo,
            inProgress: s.statusInProgress,
            done: s.statusDone,
            unassigned: s.assigneeUnassigned,
            overdue: s.filterChipOverdue,
            today: s.dueWindowToday,
            thisWeek: s.dueWindowThisWeek,
            later: s.dueWindowLater,
            noDueDate: s.dueWindowNoDueDate,
          ),
        );

        return TaskListScreen(
          banner: LastUpdatedNote(mirrorKey: TaskRepository.mirrorKey(eventId)),
          groups: groups,
          progress: taskProgress(tasks, now),
          event: widget.event,
          currentUserId: uid,
          filter: filter,
          crews: crews,
          assigneeNames: memberNames,
          selectedId: widget.selectedId,
          detail: detail,
          scrollController: _scroll,
          onFilterChanged: _filterController.set,
          onCreateTask: () => _onCreate(memberNames, crews),
          onStatusChanged: _onStatusChanged,
          onUnauthorizedStatusTap: () => _say(s.statusNotAllowed),
          onExportPdf: () => _exportPdf(tasks, memberNames),
          onBack: _back,
          onTaskTap: _open,
        );
      },
      loading: () => bare(
        CpLoadingState.rows(
          key: const Key('tasks.list.loading'),
          semanticLabel: s.tasksAppBarTitle,
        ),
      ),
      error: (e, _) => bare(
        CpErrorState(
          title: s.loadFailed,
          message: userMessageFor(
            e,
            strings: context.strings.errors,
            fallback: context.strings.errors.genericFallback,
          ),
          retryLabel: context.strings.people.retry,
          retryKey: const Key('tasks.list.retry'),
          onRetry: () => ref.invalidate(taskListProvider(eventId)),
        ),
      ),
    );
  }
}
