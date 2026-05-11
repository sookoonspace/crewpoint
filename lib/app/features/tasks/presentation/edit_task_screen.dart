import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/form_card_shell.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/assignee_picker.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/budget_estimate_field.dart';

/// Edit screen for an existing task. Mirrors `CreateTaskScreen` shape:
/// pure presentation, emits the updated `TaskModel` via `onSubmit`.
///
/// Differences from create:
/// - Pre-fills from `initial`
/// - `firstDate: DateTime(2000)` on due-date picker so past-due tasks can be
///   re-edited without the picker springing to today
/// - Renders an orphan assignee (one who left the event) as a disabled row
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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      // Allow past dates so admins can correct mistakes (e.g. a task that
      // was assigned to "yesterday" by accident).
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final budget = parseBudgetEstimate(
      _budgetController.text,
      locale: localeTag,
    );

    final updated = widget.initial.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      assigneeId: _assigneeId,
      dueDate: _dueDate,
      budgetEstimate: budget,
      clearBudgetEstimate: budget == null,
    );
    widget.onSubmit?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
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
                spacing: AppSpacing.lg,
                children: [
                  CustomTextField(
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
                  CustomTextField(
                    key: const Key('tasks.edit.description'),
                    hintText: 'Description (optional)',
                    controller: _descriptionController,
                    maxLines: 3,
                    prefixIcon: const Icon(Icons.description),
                  ),
                  AssigneePicker(
                    memberIds: widget.event.memberIds,
                    displayNames: widget.displayNames,
                    orphanAssigneeId: orphan,
                    selected: _assigneeId,
                    onChanged: (value) => setState(() => _assigneeId = value),
                  ),
                  BudgetEstimateField(
                    key: const Key('tasks.edit.budget'),
                    controller: _budgetController,
                    currencyCode: widget.event.currency,
                  ),
                  InkWell(
                    key: const Key('tasks.edit.dueDate'),
                    onTap: _pickDueDate,
                    borderRadius: AppRadius.borderLg,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.borderLg,
                        ),
                      ),
                      child: Text(
                        _dueDate == null
                            ? 'No due date'
                            : DateFormat.yMMMd().format(_dueDate!),
                        style: TextStyle(
                          color: _dueDate == null
                              ? AppColors.mediumGrey
                              : AppColors.charcoal,
                        ),
                      ),
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
