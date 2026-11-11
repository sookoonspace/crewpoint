import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/create_task_screen.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/edit_task_screen.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/task_detail_screen.dart';

/// Loads task + checklist live streams and wires mutations through the
/// repository. Routing-friendly entry point at /event/:eventId/tasks/:taskId.
class EventTaskDetailPage extends ConsumerWidget {
  const EventTaskDetailPage({
    super.key,
    required this.event,
    required this.taskId,
  });

  final EventModel event;
  final String taskId;

  String? _currentUserId(WidgetRef ref) {
    final auth = ref.read(authProvider);
    return auth is Authenticated ? auth.user.uid : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = _currentUserId(ref);
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }

    final budgets =
        ref.watch(taskBudgetsProvider(event.id)).value ??
        const <String, double>{};
    final asyncTasks = ref
        .watch(taskListProvider(event.id))
        .whenData((tasks) => withBudgets(tasks, budgets));
    final asyncChecklist = ref.watch(
      taskChecklistProvider((eventId: event.id, taskId: taskId)),
    );
    final repo = ref.watch(taskRepositoryProvider);
    final crews = ref.watch(eventCrewsProvider(event.id)).value ?? const [];
    final managesTasks = event.can(uid, 'tasks.manage');

    return asyncTasks.when(
      data: (tasks) {
        final task = tasks
            .where((t) => t.id == taskId)
            .cast<TaskModel?>()
            .firstWhere((t) => true, orElse: () => null);
        if (task == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Task'), elevation: 0),
            body: const Center(child: Text('Task not found')),
          );
        }

        final canEdit = task.canEditOrDelete(
          managesTasks: managesTasks,
          currentUserId: uid,
        );
        final canChangeStatus = task.canChangeStatus(
          managesTasks: managesTasks,
          currentUserId: uid,
        );

        // Names of the people this task shows, including an assignee or
        // completer who has since left (Req 37), read one by one (Req 43a).
        final asyncUsers = ref.watch(
          peopleByIdProvider(
            PeopleKey(event.id, [?task.assigneeId, ?task.completedBy]),
          ),
        );
        // displayName when set, email as second fallback. TaskDetailScreen
        // shows "Unknown member" if even this is null/empty (offline or
        // user doc not yet hydrated).
        String? labelFor(String uid) => asyncUsers.maybeWhen(
          data: (users) {
            final user = users[uid];
            if (user == null) return null;
            final name = user.displayName;
            if (name != null && name.isNotEmpty) return name;
            if (user.email.isNotEmpty) return user.email;
            return null;
          },
          orElse: () => null,
        );
        final assigneeName = task.assigneeId == null
            ? null
            : labelFor(task.assigneeId!);
        final completedByName = task.completedBy == null
            ? null
            : labelFor(task.completedBy!);

        final displayNamesMap = asyncUsers.maybeWhen(
          data: (users) => {
            for (final entry in users.entries)
              entry.key: entry.value.displayName ?? '',
          },
          orElse: () => <String, String>{},
        );

        return asyncChecklist.when(
          data: (items) => TaskDetailScreen(
            task: task,
            event: event,
            checklist: items,
            canEditTask: canEdit,
            canChangeStatus: canChangeStatus,
            assigneeName: assigneeName,
            completedByName: completedByName,
            onEdit: canEdit
                ? () async {
                    final updated = await Navigator.of(context).push<TaskModel>(
                      MaterialPageRoute(
                        builder: (_) => EditTaskScreen(
                          event: event,
                          currentUserId: uid,
                          initial: task,
                          displayNames: displayNamesMap,
                          crews: crews,
                          onSubmit: (t) => Navigator.of(context).pop(t),
                        ),
                      ),
                    );
                    if (updated == null || !context.mounted) return;
                    // The figure is saved only when someone allowed to
                    // set it changed it (Req 36).
                    final budgetChanged =
                        event.can(uid, 'budget.edit') &&
                        updated.budgetEstimate != task.budgetEstimate;
                    final ok = await repo.updateTask(
                      updated,
                      budgetEditedBy: budgetChanged ? uid : null,
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not save changes'),
                          backgroundColor: AppColors.terracotta,
                        ),
                      );
                    }
                  }
                : null,
            onDuplicate: () async {
              // Reads checklist from the already-watched stream so the
              // copy carries every item from the source. Any viewer
              // (creator/admin/member) may duplicate; the new task gets
              // their uid as createdBy.
              final duplicate = task.duplicate(
                currentUserId: uid,
                checklist: items,
              );
              final edited = await Navigator.of(context).push<TaskModel>(
                MaterialPageRoute(
                  builder: (_) => CreateTaskScreen(
                    event: event,
                    currentUserId: uid,
                    initial: duplicate,
                    displayNames: displayNamesMap,
                    crews: crews,
                    onSubmit: (t) => Navigator.of(context).pop(t),
                  ),
                ),
              );
              if (edited == null || !context.mounted) return;
              final ok = await repo.createTaskWithChecklist(
                edited,
                edited.checklistItems,
              );
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not duplicate task'),
                    backgroundColor: AppColors.terracotta,
                  ),
                );
              }
            },
            onDelete: canEdit
                ? () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete this task?'),
                        content: const Text(
                          'This cannot be undone. Members will lose the task '
                          'and any checklist items.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: AppColors.terracotta),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    final ok = await repo.deleteTask(task.id);
                    if (!ok || !context.mounted) return;
                    Navigator.of(context).pop();
                  }
                : null,
            onChecklistToggle: (item, isCompleted) {
              // Assignee uses the toggle-only path; creator/admin can use
              // either, but toggle is the safer write.
              repo.toggleChecklistItem(
                eventId: event.id,
                taskId: taskId,
                itemId: item.id,
                isCompleted: isCompleted,
              );
            },
            onChecklistAdd: canEdit
                ? (id, text) => repo.addChecklistItem(
                    eventId: event.id,
                    taskId: taskId,
                    id: id,
                    text: text,
                    sortOrder: items.length,
                  )
                : null,
            onChecklistEditText: canEdit
                ? (item, text) => repo.updateChecklistItem(
                    eventId: event.id,
                    taskId: taskId,
                    itemId: item.id,
                    text: text,
                  )
                : null,
            onChecklistDelete: canEdit
                ? (item) => repo.deleteChecklistItem(
                    eventId: event.id,
                    taskId: taskId,
                    itemId: item.id,
                  )
                : null,
          ),
          loading: () => Scaffold(
            appBar: AppBar(title: Text(task.title), elevation: 0),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: Text(task.title), elevation: 0),
            body: Center(
              child: Text(
                userMessageFor(
                  e,
                  strings: context.strings.errors,
                  fallback: context.strings.errors.genericFallback,
                ),
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Task'), elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Task'), elevation: 0),
        body: Center(
          child: Text(
            userMessageFor(
              e,
              strings: context.strings.errors,
              fallback: context.strings.errors.genericFallback,
            ),
          ),
        ),
      ),
    );
  }
}
