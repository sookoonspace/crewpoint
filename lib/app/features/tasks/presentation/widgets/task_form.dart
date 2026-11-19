import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/layout/cp_list_detail.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_currency_field.dart'
    show parseCurrencyInput;
import 'package:crewpoint_app/app/features/dashboard/domain/models/crew.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/assignee_picker.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/crew_picker.dart';

/// What the task form holds when saved.
typedef TaskFormValues = ({
  String title,
  String? description,
  String? assigneeId,
  int priority,

  /// The chosen calendar day, not yet in the event's zone.
  DateTime? dueDay,

  /// The figure entered, or null for none. Read only when [editsBudget].
  double? budget,
  String? crewId,
});

/// The task form shared by Create and Edit, in the Person form's pattern
/// (Spec #186): a top bar with close, cards of fields, and the save button
/// in a bar at the bottom. Leaving with changes asks first, and so does
/// choosing another task while it shows beside the list (Req 23).
///
/// Keys start with [keyPrefix], such as `tasks.create`.
class TaskForm extends StatefulWidget {
  const TaskForm({
    super.key,
    required this.keyPrefix,
    required this.title,
    required this.saveLabel,
    required this.event,
    required this.editsBudget,
    required this.onSubmit,
    this.initial,
    this.displayNames = const {},
    this.crews = const [],
    this.onCancel,
  });

  final String keyPrefix;
  final String title;
  final String saveLabel;
  final EventModel event;

  /// Whether the viewer may set a budget figure (`budget.edit`, Req 36).
  final bool editsBudget;
  final ValueChanged<TaskFormValues> onSubmit;

  /// The task being edited or copied.
  final TaskModel? initial;
  final Map<String, String> displayNames;

  /// The event's crews (Req 72). The crew field shows only when there are
  /// some, or the task already has one.
  final List<CrewModel> crews;

  /// Closes a form shown in place rather than as its own page.
  final VoidCallback? onCancel;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  static const _maxTitle = 120;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _budget;
  String? _assigneeId;
  String? _assigneeName;
  DateTime? _dueDay;
  late int _priority;
  String? _crewId;
  late final TaskFormValues _start;
  late final String _startBudget;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _title = TextEditingController(text: t?.title ?? '')..addListener(_changed);
    _description = TextEditingController(text: t?.description ?? '')
      ..addListener(_changed);
    _budget = TextEditingController(text: t?.budgetEstimate?.toString() ?? '')
      ..addListener(_changed);
    _assigneeId = t?.assigneeId;
    _assigneeName = widget.displayNames[_assigneeId];
    _dueDay = t?.dueDate == null ? null : widget.event.calendarDay(t!.dueDate!);
    _priority = t?.priority ?? 0;
    _crewId = t?.crewId;
    _start = _values;
    _startBudget = _budget.text.trim();
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _budget.dispose();
    super.dispose();
  }

  double? get _budgetValue {
    try {
      return parseCurrencyInput(
        _budget.text,
        locale: Localizations.localeOf(context).toLanguageTag(),
      );
    } on FormatException {
      return null;
    }
  }

  TaskFormValues get _values => (
    title: _title.text.trim(),
    description: _description.text.trim().isEmpty
        ? null
        : _description.text.trim(),
    assigneeId: _assigneeId,
    priority: _priority,
    dueDay: _dueDay,
    budget: null,
    crewId: _crewId,
  );

  bool get _dirty =>
      !_leaving && (_values != _start || _budget.text.trim() != _startBudget);

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final v = _values;
    _leaving = true;
    widget.onSubmit((
      title: v.title,
      description: v.description,
      assigneeId: v.assigneeId,
      priority: v.priority,
      dueDay: v.dueDay,
      budget: widget.editsBudget ? _budgetValue : null,
      crewId: v.crewId,
    ));
  }

  /// Asks before dropping changes. True means leave.
  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final roles = context.strings.roles;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => CpDialog(
        title: roles.discardTitle,
        message: roles.discardBody,
        actions: [
          CpButton.text(
            key: const Key('tasks.discard.keep'),
            label: roles.keepEditing,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          CpButton.destructive(
            key: const Key('tasks.discard.confirm'),
            label: roles.discard,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _leave() async {
    final navigator = Navigator.of(context);
    if (!await _confirmLeave() || !mounted) return;
    setState(() => _leaving = true);
    final cancel = widget.onCancel;
    if (cancel != null) {
      cancel();
    } else {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.tasks;
    final p = widget.keyPrefix;
    final orphan =
        widget.initial?.assigneeId != null &&
        !widget.event.memberIds.contains(widget.initial!.assigneeId);

    Widget card(List<Widget> children) => CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: children,
      ),
    );

    final body = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          KeyedSubtree(
            key: Key('$p.section.details'),
            child: card([
              CpTextField(
                key: Key('$p.title'),
                label: s.titleLabel,
                hint: s.taskTitleHint,
                controller: _title,
                required: true,
                requiredLabel: context.strings.groupEntry.required,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final title = value?.trim() ?? '';
                  if (title.isEmpty) return s.titleRequired;
                  if (title.length > _maxTitle) {
                    return s.titleTooLong(_maxTitle);
                  }
                  return null;
                },
              ),
              CpTextField(
                key: Key('$p.description'),
                label: s.descriptionLabel,
                hint: s.descriptionOptionalHint,
                controller: _description,
                maxLines: 3,
              ),
            ]),
          ),
          CpSectionHeader(title: s.sectionAssignment),
          KeyedSubtree(
            key: Key('$p.section.assignment'),
            child: card([
              AssigneePicker(
                eventId: widget.event.id,
                words: widget.event.words,
                selected: _assigneeId,
                selectedName: _assigneeName,
                selectedLeft:
                    orphan && _assigneeId == widget.initial?.assigneeId,
                onChanged: (uid, name) => setState(() {
                  _assigneeId = uid;
                  _assigneeName = name;
                }),
              ),
              if (widget.crews.isNotEmpty || _crewId != null)
                CrewPicker(
                  crews: widget.crews,
                  crewWord: widget.event.words.one('crew'),
                  selected: _crewId,
                  // Only a pick changes the crew, so one that has not loaded
                  // yet is never cleared by mistake.
                  onChanged: (value) => setState(() => _crewId = value),
                ),
              CpChoiceChips<int>(
                key: Key('$p.priority'),
                label: s.fieldPriority,
                choices: [
                  CpChoice(0, s.priorityNone, key: Key('$p.priority.0')),
                  CpChoice(1, s.priorityLow, key: Key('$p.priority.1')),
                  CpChoice(2, s.priorityMedium, key: Key('$p.priority.2')),
                  CpChoice(3, s.priorityHigh, key: Key('$p.priority.3')),
                ],
                selected: {_priority},
                onChanged: (picked) => setState(
                  () => _priority = picked.isEmpty ? 0 : picked.first,
                ),
              ),
            ]),
          ),
          CpSectionHeader(title: s.sectionTimingAndBudget),
          KeyedSubtree(
            key: Key('$p.section.timing'),
            child: card([
              CpDateField(
                key: Key('$p.dueDate'),
                fieldKey: Key('$p.dueDate.field'),
                clearKey: Key('$p.dueDate.clear'),
                label: s.dueDateLabel,
                value: _dueDay,
                placeholder: s.dueWindowNoDueDate,
                clearLabel: s.clearDueDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                format: (d) => DateFormat.yMMMd().format(d),
                onChanged: (v) => setState(() => _dueDay = v),
              ),
              if (widget.editsBudget)
                CpTextField(
                  key: Key('$p.budget'),
                  label: s.budgetEstimateLabel,
                  help: widget.event.currency,
                  prefixIcon: CpIcons.currency,
                  controller: _budget,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    try {
                      parseCurrencyInput(
                        value ?? '',
                        locale: Localizations.localeOf(context).toLanguageTag(),
                      );
                      return null;
                    } on FormatException {
                      return s.budgetInvalid;
                    }
                  },
                ),
            ]),
          ),
        ],
      ),
    );

    final saveBar = Material(
      color: cp.colors.surface,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cp.colors.border)),
          ),
          child: Padding(
            padding: EdgeInsets.all(cp.space.md),
            // heightFactor 1: the bar is only as tall as its button.
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              heightFactor: 1,
              child: CpButton(
                key: Key('$p.save'),
                label: widget.saveLabel,
                onPressed: _submit,
              ),
            ),
          ),
        ),
      ),
    );

    return PopScope(
      // A form in place never pops its page; one of its own asks first.
      canPop: widget.onCancel == null && !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: CpUnsavedChanges(
        dirty: _dirty,
        child: Scaffold(
          backgroundColor: cp.colors.background,
          appBar: CpTopBar(
            title: widget.title,
            leadingIcon: CpIcons.actionClose,
            leadingKey: Key('$p.close'),
            leadingTooltip: MaterialLocalizations.of(
              context,
            ).closeButtonTooltip,
            onLeading: _leave,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              cp.space.lg,
              cp.space.sm,
              cp.space.lg,
              cp.space.xxl,
            ),
            child: ContentMaxWidth(
              key: Key('$p.body.clamped'),
              maxWidth: cp.sizes.phoneColumn,
              child: body,
            ),
          ),
          bottomNavigationBar: saveBar,
        ),
      ),
    );
  }
}
