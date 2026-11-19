import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/crew.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_form.dart';

/// Edits an existing task. Pure presentation: emits the updated
/// `TaskModel` through [onSubmit]. Past due dates are allowed.
///
/// With [onCancel] it shows in place, as beside the Tasks list, and closing
/// it calls [onCancel] instead of leaving the page.
class EditTaskScreen extends StatelessWidget {
  const EditTaskScreen({
    super.key,
    required this.event,
    required this.currentUserId,
    required this.initial,
    this.displayNames = const {},
    this.crews = const [],
    this.onSubmit,
    this.onCancel,
  });

  final EventModel event;
  final String currentUserId;
  final TaskModel initial;
  final Map<String, String> displayNames;

  /// The event's crews (Req 72).
  final List<CrewModel> crews;
  final ValueChanged<TaskModel>? onSubmit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.tasks;
    // Without `budget.edit` the field is hidden and the figure kept (Req 36).
    final editsBudget = event.can(currentUserId, 'budget.edit');
    return TaskForm(
      keyPrefix: 'tasks.edit',
      title: s.editTaskTitle,
      saveLabel: s.saveChangesCta,
      event: event,
      editsBudget: editsBudget,
      initial: initial,
      displayNames: displayNames,
      crews: crews,
      onCancel: onCancel,
      onSubmit: (v) => onSubmit?.call(
        initial.copyWith(
          title: v.title,
          description: v.description,
          clearDescription: v.description == null,
          assigneeId: v.assigneeId,
          clearAssigneeId: v.assigneeId == null,
          priority: v.priority,
          dueDate: v.dueDay == null ? null : event.startOfDay(v.dueDay!),
          clearDueDate: v.dueDay == null,
          budgetEstimate: editsBudget ? v.budget : initial.budgetEstimate,
          clearBudgetEstimate: editsBudget && v.budget == null,
          crewId: v.crewId,
          clearCrewId: v.crewId == null,
        ),
      ),
    );
  }
}
