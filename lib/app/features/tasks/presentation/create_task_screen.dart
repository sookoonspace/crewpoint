import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
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

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({
    super.key,
    required this.event,
    required this.currentUserId,
    this.displayNames = const {},
    this.onSubmit,
  });

  final EventModel event;
  final String currentUserId;
  final Map<String, String> displayNames;
  final ValueChanged<TaskModel>? onSubmit;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  String? _assigneeId;
  DateTime? _dueDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
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

    final task = TaskModel(
      id: const Uuid().v4(),
      eventId: widget.event.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      assigneeId: _assigneeId,
      createdBy: widget.currentUserId,
      dueDate: _dueDate,
      budgetEstimate: budget,
    );

    widget.onSubmit?.call(task);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Create Task'),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.xl,
        ),
        child: ContentMaxWidth(
          key: const Key('createTask.body.clamped'),
          maxWidth: 480,
          child: FormCardShell(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: .start,
                spacing: AppSpacing.lg,
                children: [
                  CustomTextField(
                    key: const Key('tasks.create.title'),
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
                    key: const Key('tasks.create.description'),
                    hintText: 'Description (optional)',
                    controller: _descriptionController,
                    maxLines: 3,
                    prefixIcon: const Icon(Icons.description),
                  ),
                  AssigneePicker(
                    memberIds: widget.event.memberIds,
                    displayNames: widget.displayNames,
                    selected: _assigneeId,
                    onChanged: (value) => setState(() => _assigneeId = value),
                  ),
                  BudgetEstimateField(
                    controller: _budgetController,
                    currencyCode: widget.event.currency,
                  ),
                  InkWell(
                    key: const Key('tasks.create.dueDate'),
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
                    key: const Key('tasks.create.save'),
                    label: 'Create Task',
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
