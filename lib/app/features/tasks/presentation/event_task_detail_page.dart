import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/create_task_screen.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/edit_task_screen.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/task_detail_screen.dart';

/// Loads one task and its checklist, and saves through the repository.
/// The route `/event/:eventId/tasks/:taskId`, beside the Tasks list from
/// 840 px (Spec #186 Req 23).
///
/// Editing happens in place, so beside the list the form keeps its place
/// and choosing another task with unsaved edits asks first.
class EventTaskDetailPage extends ConsumerStatefulWidget {
  const EventTaskDetailPage({
    super.key,
    required this.event,
    required this.taskId,
  });

  final EventModel event;
  final String taskId;

  @override
  ConsumerState<EventTaskDetailPage> createState() =>
      _EventTaskDetailPageState();
}

class _EventTaskDetailPageState extends ConsumerState<EventTaskDetailPage> {
  bool _editing = false;

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

  Future<bool> _confirmDelete() async {
    final s = context.strings.tasks;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => CpDialog(
        title: s.deleteTitle,
        message: s.deleteBody,
        actions: [
          CpButton.text(
            key: const Key('tasks.detail.delete.cancel'),
            label: s.cancel,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          CpButton.destructive(
            key: const Key('tasks.detail.delete.confirm'),
            label: s.detailDelete,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final taskId = widget.taskId;
    final s = context.strings.tasks;

    Widget bare(String title, Widget body) => Scaffold(
      appBar: CpTopBar(
        title: title,
        leadingKey: const Key('tasks.detail.back'),
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: () => Navigator.of(context).maybePop(),
      ),
      body: body,
    );
    Widget failed(Object e) => CpErrorState(
      title: s.loadFailed,
      message: userMessageFor(
        e,
        strings: context.strings.errors,
        fallback: context.strings.errors.genericFallback,
      ),
      retryLabel: context.strings.people.retry,
      retryKey: const Key('tasks.detail.retry'),
      onRetry: () => ref.invalidate(taskListProvider(event.id)),
    );

    final uid = _currentUserId();
    if (uid == null) {
      return bare(
        s.taskWord,
        CpEmptyState(icon: CpIcons.lock, title: s.signInRequiredTitle),
      );
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
        final task = tasks.where((t) => t.id == taskId).firstOrNull;
        if (task == null) {
          return bare(
            s.taskWord,
            CpEmptyState(
              key: const Key('tasks.detail.notFound'),
              icon: CpIcons.navTasks,
              title: s.notFound,
            ),
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
        // The display name, else the email; null shows "Unknown member".
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
        final displayNames = asyncUsers.maybeWhen(
          data: (users) => {
            for (final entry in users.entries)
              entry.key: entry.value.displayName ?? '',
          },
          orElse: () => <String, String>{},
        );

        if (_editing && canEdit) {
          return EditTaskScreen(
            event: event,
            currentUserId: uid,
            initial: task,
            displayNames: displayNames,
            crews: crews,
            onCancel: () => setState(() => _editing = false),
            onSubmit: (updated) async {
              setState(() => _editing = false);
              final failed = s.saveFailed;
              // The figure is saved only when someone allowed to set it
              // changed it (Req 36).
              final budgetChanged =
                  event.can(uid, 'budget.edit') &&
                  updated.budgetEstimate != task.budgetEstimate;
              final ok = await repo.updateTask(
                updated,
                budgetEditedBy: budgetChanged ? uid : null,
              );
              if (!ok) _say(failed);
            },
          );
        }

        return asyncChecklist.when(
          data: (items) => TaskDetailScreen(
            task: task,
            event: event,
            checklist: items,
            canEditTask: canEdit,
            canChangeStatus: canChangeStatus,
            assigneeName: task.assigneeId == null
                ? null
                : labelFor(task.assigneeId!),
            completedByName: task.completedBy == null
                ? null
                : labelFor(task.completedBy!),
            crewName: crews.where((c) => c.id == task.crewId).firstOrNull?.name,
            onEdit: canEdit ? () => setState(() => _editing = true) : null,
            onDuplicate: () async {
              // The copy carries every checklist item, and is the viewer's
              // own (`createdBy`), so anyone may duplicate.
              final failed = s.duplicateFailed;
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
                    displayNames: displayNames,
                    crews: crews,
                    onSubmit: (t) => Navigator.of(context).pop(t),
                  ),
                ),
              );
              if (edited == null) return;
              final ok = await repo.createTaskWithChecklist(
                edited,
                edited.checklistItems,
              );
              if (!ok) _say(failed);
            },
            onDelete: canEdit
                ? () async {
                    if (!await _confirmDelete()) return;
                    final ok = await repo.deleteTask(task.id);
                    if (!ok || !context.mounted) return;
                    Navigator.of(context).pop();
                  }
                : null,
            onChecklistToggle: (item, isCompleted) {
              // The assignee uses the toggle-only path; it is the safer
              // write for everyone.
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
          loading: () => bare(
            task.title,
            CpLoadingState(
              key: const Key('tasks.detail.loading'),
              semanticLabel: task.title,
            ),
          ),
          error: (e, _) => bare(task.title, failed(e)),
        );
      },
      loading: () => bare(
        s.taskWord,
        CpLoadingState(
          key: const Key('tasks.detail.loading'),
          semanticLabel: s.taskWord,
        ),
      ),
      error: (e, _) => bare(s.taskWord, failed(e)),
    );
  }
}
