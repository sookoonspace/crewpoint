import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/crew.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_form.dart';

/// A new task, or a copy of one ([initial], the Duplicate flow). Pure
/// presentation: emits the new `TaskModel` through [onSubmit].
class CreateTaskScreen extends StatelessWidget {
  const CreateTaskScreen({
    super.key,
    required this.event,
    required this.currentUserId,
    this.initial,
    this.displayNames = const {},
    this.crews = const [],
    this.onSubmit,
  });

  final EventModel event;
  final String currentUserId;

  /// Optional pre-fill for the Duplicate flow: the form opens filled from
  /// it, keeping its new ID and checklist. `eventId` is always `event.id`.
  final TaskModel? initial;
  final Map<String, String> displayNames;

  /// The event's crews (Req 72).
  final List<CrewModel> crews;
  final ValueChanged<TaskModel>? onSubmit;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.tasks;
    // Setting a task's budget figure needs `budget.edit` (Req 36); a copied
    // figure is dropped for someone who cannot set one.
    final editsBudget = event.can(currentUserId, 'budget.edit');
    return TaskForm(
      keyPrefix: 'tasks.create',
      title: s.createTaskTitle,
      saveLabel: s.createTaskCta,
      event: event,
      editsBudget: editsBudget,
      initial: initial,
      displayNames: displayNames,
      crews: crews,
      onSubmit: (v) => onSubmit?.call(
        TaskModel(
          // A copy keeps the ID the duplicate factory gave it.
          id: initial?.id ?? const Uuid().v4(),
          eventId: event.id,
          title: v.title,
          description: v.description,
          assigneeId: v.assigneeId,
          createdBy: currentUserId,
          priority: v.priority,
          dueDate: v.dueDay == null ? null : event.startOfDay(v.dueDay!),
          budgetEstimate: editsBudget ? v.budget : null,
          crewId: v.crewId,
          checklistItems: initial?.checklistItems ?? const [],
        ),
      ),
    );
  }
}
