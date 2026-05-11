import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_export_pipeline.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/create_task_screen.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/task_list_screen.dart';

/// Event-scoped tasks tab. Reads the live `taskListProvider(eventId)` stream
/// and routes mutations through `taskRepositoryProvider`.
class EventTasksPage extends ConsumerStatefulWidget {
  const EventTasksPage({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<EventTasksPage> createState() => _EventTasksPageState();
}

class _EventTasksPageState extends ConsumerState<EventTasksPage> {
  TaskStatus? _filter;

  String? _currentUserId() {
    final auth = ref.read(authProvider);
    return auth is Authenticated ? auth.user.uid : null;
  }

  Future<void> _onCreate(Map<String, String> displayNames) async {
    final uid = _currentUserId();
    if (uid == null) return;
    final created = await Navigator.of(context).push<TaskModel>(
      MaterialPageRoute(
        builder: (_) => CreateTaskScreen(
          event: widget.event,
          currentUserId: uid,
          displayNames: displayNames,
          onSubmit: (task) => Navigator.of(context).pop(task),
        ),
      ),
    );
    if (created == null) return;
    final ok = await ref.read(taskRepositoryProvider).createTask(created);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create task'),
          backgroundColor: AppColors.terracotta,
        ),
      );
    }
  }

  Future<void> _onStatusChanged(TaskModel task, TaskStatus newStatus) async {
    final ok = await ref
        .read(taskRepositoryProvider)
        .updateStatus(
          eventId: task.eventId,
          taskId: task.id,
          newStatus: newStatus,
        );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update status'),
          backgroundColor: AppColors.terracotta,
        ),
      );
    }
  }

  void _onUnauthorizedTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Only the assignee or an admin can change this'),
        backgroundColor: AppColors.terracotta,
      ),
    );
  }

  Future<void> _exportPdf(
    List<TaskModel> tasks,
    Map<String, String> memberNames,
  ) async {
    try {
      await runTaskPdfExport(
        event: widget.event,
        tasks: tasks,
        memberNames: memberNames,
        exporter: ref.read(fileExporterProvider),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't generate report"),
          backgroundColor: AppColors.terracotta,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUserId();
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }

    final asyncTasks = ref.watch(taskListProvider(widget.event.id));
    final asyncUsers = ref.watch(usersByIdProvider(widget.event.memberIds));

    return asyncTasks.when(
      data: (tasks) {
        final memberNames = asyncUsers.maybeWhen(
          data: (users) => {
            for (final entry in users.entries)
              entry.key: entry.value.displayName ?? '',
          },
          orElse: () => <String, String>{},
        );
        return TaskListScreen(
          tasks: tasks,
          event: widget.event,
          currentUserId: uid,
          selectedFilter: _filter,
          onFilterChanged: (status) => setState(() => _filter = status),
          onCreateTask: () => _onCreate(memberNames),
          onStatusChanged: _onStatusChanged,
          onUnauthorizedStatusTap: _onUnauthorizedTap,
          onExportPdf: () => _exportPdf(tasks, memberNames),
          onTaskTap: (task) {
            // Detail screen lands in Phase 2.
            context.push(
              '/dashboard/event/${widget.event.id}/tasks/${task.id}',
              extra: task,
            );
          },
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('Tasks'),
          backgroundColor: AppColors.cream,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('Tasks'),
          backgroundColor: AppColors.cream,
          elevation: 0,
        ),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}
