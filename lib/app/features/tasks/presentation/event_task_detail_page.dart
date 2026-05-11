import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
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

    final asyncTasks = ref.watch(taskListProvider(event.id));
    final asyncChecklist = ref.watch(
      taskChecklistProvider((eventId: event.id, taskId: taskId)),
    );
    final repo = ref.watch(taskRepositoryProvider);
    final isOwner = event.isOwner(uid);
    final isAdmin = event.isAdmin(uid);

    return asyncTasks.when(
      data: (tasks) {
        final task = tasks
            .where((t) => t.id == taskId)
            .cast<TaskModel?>()
            .firstWhere((t) => true, orElse: () => null);
        if (task == null) {
          return Scaffold(
            backgroundColor: AppColors.cream,
            appBar: AppBar(
              title: const Text('Task'),
              backgroundColor: AppColors.cream,
              elevation: 0,
            ),
            body: const Center(child: Text('Task not found')),
          );
        }

        final canEdit = task.canEditOrDelete(
          isOwner: isOwner,
          isAdmin: isAdmin,
          currentUserId: uid,
        );
        final canChangeStatus = task.canChangeStatus(
          isOwner: isOwner,
          isAdmin: isAdmin,
          currentUserId: uid,
        );

        // Resolve assignee display name via usersByIdProvider. Include the
        // orphan assignee UID (one who left the event) so its name still
        // hydrates for the "no longer in event" affordance.
        final uidsToResolve = <String>[
          ...event.memberIds,
          if (task.assigneeId != null &&
              !event.memberIds.contains(task.assigneeId))
            task.assigneeId!,
        ];
        final asyncUsers = ref.watch(usersByIdProvider(uidsToResolve));
        final assigneeName = task.assigneeId == null
            ? null
            : asyncUsers.maybeWhen(
                data: (users) => users[task.assigneeId]?.displayName,
                orElse: () => null,
              );

        return asyncChecklist.when(
          data: (items) => TaskDetailScreen(
            task: task,
            event: event,
            checklist: items,
            canEditTask: canEdit,
            canChangeStatus: canChangeStatus,
            assigneeName: assigneeName,
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
            backgroundColor: AppColors.cream,
            appBar: AppBar(
              title: Text(task.title),
              backgroundColor: AppColors.cream,
              elevation: 0,
            ),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            backgroundColor: AppColors.cream,
            appBar: AppBar(
              title: Text(task.title),
              backgroundColor: AppColors.cream,
              elevation: 0,
            ),
            body: Center(child: Text('Checklist error: $e')),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('Task'),
          backgroundColor: AppColors.cream,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('Task'),
          backgroundColor: AppColors.cream,
          elevation: 0,
        ),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}
