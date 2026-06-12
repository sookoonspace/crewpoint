import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
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

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({
    super.key,
    required this.event,
    required this.currentUserId,
    this.initial,
    this.displayNames = const {},
    this.onSubmit,
  });

  final EventModel event;
  final String currentUserId;

  /// Optional pre-fill for the Duplicate flow. When non-null, the form
  /// opens populated from this model (title, description, assignee, due
  /// date, budget, priority). `eventId` is taken from `event.id` either
  /// way; the duplicate factory sets the new id + clears completion
  /// fields before passing in.
  final TaskModel? initial;
  final Map<String, String> displayNames;
  final ValueChanged<TaskModel>? onSubmit;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
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
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _budgetController = TextEditingController(
      text: initial?.budgetEstimate?.toString() ?? '',
    );
    _assigneeId = initial?.assigneeId;
    _dueDate = initial?.dueDate;
    _priority = initial?.priority ?? 0;
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

    final task = TaskModel(
      // When duplicating, preserve the pre-set id (the duplicate factory
      // assigned a fresh UUID). Otherwise mint a new id.
      id: widget.initial?.id ?? const Uuid().v4(),
      eventId: widget.event.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      assigneeId: _assigneeId,
      createdBy: widget.currentUserId,
      priority: _priority,
      dueDate: _dueDate,
      budgetEstimate: budget,
      checklistItems: widget.initial?.checklistItems ?? const [],
    );

    widget.onSubmit?.call(task);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.tasks;
    return Scaffold(
      appBar: AppBar(title: Text(s.createTaskTitle), elevation: 0),
      body: SingleChildScrollView(
        // Bottom padding is doubled vs top so the Create Task CTA at
        // the form's tail clears the persistent ResponsiveShell
        // NavigationBar with comfortable breathing room on iPhone 12
        // mini — the previous symmetric `xl` (24) put the button only
        // ~10 px above the nav.
        padding: EdgeInsets.fromLTRB(
          Breakpoints.screenHorizontalPadding(context),
          AppSpacing.xl,
          Breakpoints.screenHorizontalPadding(context),
          AppSpacing.xxxl,
        ),
        child: ContentMaxWidth(
          key: const Key('createTask.body.clamped'),
          maxWidth: 480,
          child: FormCardShell(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: .start,
                spacing: AppSpacing.xl,
                children: [
                  AppFormSection(
                    key: const Key('tasks.create.section.details'),
                    title: s.sectionDetails,
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: AppSpacing.md,
                      children: [
                        AppTextField(
                          key: const Key('tasks.create.title'),
                          hintText: s.taskTitleHint,
                          controller: _titleController,
                          prefixIcon: const Icon(AppIcons.navTasksFilled),
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
                        // No prefixIcon: Material centres prefixIcon
                        // vertically across the field's full multi-line
                        // height, so on a 3-line description it sits
                        // orphaned below the hint. The hint alone tells
                        // the user what this field is for.
                        AppTextField(
                          key: const Key('tasks.create.description'),
                          hintText: s.descriptionOptionalHint,
                          controller: _descriptionController,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  AppFormSection(
                    key: const Key('tasks.create.section.assignment'),
                    title: s.sectionAssignment,
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: AppSpacing.md,
                      children: [
                        AssigneePicker(
                          memberIds: widget.event.memberIds,
                          displayNames: widget.displayNames,
                          selected: _assigneeId,
                          onChanged: (value) =>
                              setState(() => _assigneeId = value),
                        ),
                        AppRadioGroup<int>(
                          key: const Key('tasks.create.priority'),
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
                    key: const Key('tasks.create.section.timing'),
                    title: s.sectionTimingAndBudget,
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: AppSpacing.md,
                      children: [
                        AppDateField(
                          key: const Key('tasks.create.dueDate'),
                          labelText: s.dueDateLabel,
                          value: _dueDate,
                          onChanged: (v) => setState(() => _dueDate = v),
                        ),
                        AppCurrencyField(
                          controller: _budgetController,
                          currencyCode: widget.event.currency,
                          labelText: s.budgetEstimateLabel,
                        ),
                      ],
                    ),
                  ),
                  PrimaryButton(
                    key: const Key('tasks.create.save'),
                    label: s.createTaskCta,
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
