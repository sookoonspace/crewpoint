import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/form_card_shell.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_currency_field.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_date_field.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_form_section.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_radio_group.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/assignee_picker.dart';

/// Edit screen for an existing task. Mirrors `CreateTaskScreen`: three
/// `AppFormSection`s (Details / Assignment / Timing & Budget), pure
/// presentation, emits the updated `TaskModel` via `onSubmit`.
///
/// Past dates work — `AppDateField` defaults to `firstDate: DateTime(2000)`.
class EditTaskScreen extends StatefulWidget {
  const EditTaskScreen({
    super.key,
    required this.event,
    required this.initial,
    this.displayNames = const {},
    this.onSubmit,
  });

  final EventModel event;
  final TaskModel initial;
  final Map<String, String> displayNames;
  final ValueChanged<TaskModel>? onSubmit;

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _budgetController;
  late String? _assigneeId;
  late DateTime? _dueDate;
  late int _priority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial.title);
    _descriptionController = TextEditingController(
      text: widget.initial.description ?? '',
    );
    _budgetController = TextEditingController(
      text: widget.initial.budgetEstimate?.toString() ?? '',
    );
    _assigneeId = widget.initial.assigneeId;
    _dueDate = widget.initial.dueDate;
    _priority = widget.initial.priority;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final budget = parseCurrencyInput(
      _budgetController.text,
      locale: localeTag,
    );

    final updated = widget.initial.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      assigneeId: _assigneeId,
      priority: _priority,
      dueDate: _dueDate,
      budgetEstimate: budget,
      clearBudgetEstimate: budget == null,
    );
    widget.onSubmit?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.tasks;
    final orphan =
        widget.initial.assigneeId != null &&
            !widget.event.memberIds.contains(widget.initial.assigneeId)
        ? widget.initial.assigneeId
        : null;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Edit Task'),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.xl,
        ),
        child: ContentMaxWidth(
          key: const Key('editTask.body.clamped'),
          maxWidth: 480,
          child: FormCardShell(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: .start,
                spacing: AppSpacing.xl,
                children: [
                  AppFormSection(
                    key: const Key('tasks.edit.section.details'),
                    title: s.sectionDetails,
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: AppSpacing.md,
                      children: [
                        AppTextField(
                          key: const Key('tasks.edit.title'),
                          hintText: 'Task Title',
                          controller: _titleController,
                          prefixIcon: const Icon(Icons.task),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a title';
                            }
                            if (value.trim().length > 120) {
                              return 'Title must be 120 characters or fewer';
                            }
                            return null;
                          },
                        ),
                        AppTextField(
                          key: const Key('tasks.edit.description'),
                          hintText: 'Description (optional)',
                          controller: _descriptionController,
                          maxLines: 3,
                          prefixIcon: const Icon(Icons.description),
                        ),
                      ],
                    ),
                  ),
                  AppFormSection(
                    key: const Key('tasks.edit.section.assignment'),
                    title: s.sectionAssignment,
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: AppSpacing.md,
                      children: [
                        AssigneePicker(
                          memberIds: widget.event.memberIds,
                          displayNames: widget.displayNames,
                          orphanAssigneeId: orphan,
                          selected: _assigneeId,
                          onChanged: (value) =>
                              setState(() => _assigneeId = value),
                        ),
                        AppRadioGroup<int>(
                          key: const Key('tasks.edit.priority'),
                          labelText: s.fieldPriority,
                          value: _priority,
                          options: [
                            AppRadioOption(value: 0, label: s.priorityNone),
                            AppRadioOption(value: 1, label: s.priorityLow),
                            AppRadioOption(value: 2, label: s.priorityMedium),
                            AppRadioOption(value: 3, label: s.priorityHigh),
                          ],
                          onChanged: (v) => setState(() => _priority = v ?? 0),
                          direction: Axis.horizontal,
                        ),
                      ],
                    ),
                  ),
                  AppFormSection(
                    key: const Key('tasks.edit.section.timing'),
                    title: s.sectionTimingAndBudget,
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: AppSpacing.md,
                      children: [
                        AppDateField(
                          key: const Key('tasks.edit.dueDate'),
                          labelText: 'Due Date',
                          value: _dueDate,
                          onChanged: (v) => setState(() => _dueDate = v),
                        ),
                        AppCurrencyField(
                          key: const Key('tasks.edit.budget'),
                          controller: _budgetController,
                          currencyCode: widget.event.currency,
                          labelText: 'Budget Estimate (optional)',
                        ),
                      ],
                    ),
                  ),
                  PrimaryButton(
                    key: const Key('tasks.edit.save'),
                    label: 'Save changes',
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
