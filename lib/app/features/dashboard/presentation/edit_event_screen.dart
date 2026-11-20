import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Edit screen for an existing event (Spec #186), in the Person form's
/// pattern with Save changes in a bar at the bottom. Pure presentation — emits the
/// updated [EventModel] via `onSubmit`. Currency is in event settings, because
/// changing it can be refused.
///
/// Date pickers use `firstDate: DateTime(2000)` so admins can correct
/// back-dated events without `CreateEventScreen`'s `DateTime.now()` clamp
/// blocking the picker from opening.
class EditEventScreen extends StatefulWidget {
  const EditEventScreen({super.key, required this.initial, this.onSubmit});

  final EventModel initial;
  final ValueChanged<EventModel>? onSubmit;

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime? _startDate;
  late DateTime? _endDate;
  late EventStatus _status;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial.title);
    _descriptionController = TextEditingController(
      text: widget.initial.description ?? '',
    );
    _startDate = widget.initial.displayStart;
    _endDate = widget.initial.displayEnd;
    _status = widget.initial.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? current) {
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      // Past dates allowed so admins can fix back-dated events.
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final start = _startDate;
    final end = _endDate;
    if (start != null && end != null && end.isBefore(start)) {
      setState(() => _dateError = context.strings.templates.endBeforeStart);
      return;
    }
    setState(() => _dateError = null);

    final updated = widget.initial.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      startDate: start == null ? null : storedCalendarDate(start),
      endDate: end == null ? null : storedCalendarDate(end),
      dateOnly: true,
      clearStartDate: start == null,
      clearEndDate: end == null,
      status: _status,
    );
    widget.onSubmit?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.templates;
    final df = DateFormat.yMMMd();
    final navigator = Navigator.of(context);

    Widget card(List<Widget> children) => CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: children,
      ),
    );

    Widget dateField({
      required Key key,
      required Key clearKey,
      required String label,
      required DateTime? value,
      required ValueChanged<DateTime?> onChanged,
      String? error,
    }) => CpSelectField(
      fieldKey: key,
      label: label,
      leadingIcon: CpIcons.calendar,
      value: value == null ? null : df.format(value),
      placeholder: strings.dateOptional,
      error: error,
      onTap: () async {
        final picked = await _pickDate(value);
        if (picked != null) onChanged(picked);
      },
      onClear: () => onChanged(null),
      clearLabel: strings.clearDate,
      clearKey: clearKey,
    );

    final archived = _status == EventStatus.archived;
    final body = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          card([
            CpTextField(
              key: const Key('editEvent.title'),
              label: strings.titleLabel,
              controller: _titleController,
              required: true,
              requiredLabel: context.strings.groupEntry.required,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return strings.titleRequired;
                }
                if (value.length > 200) return strings.titleTooLong;
                return null;
              },
            ),
            CpTextField(
              key: const Key('editEvent.description'),
              label: strings.descriptionLabel,
              hint: strings.descriptionHint,
              controller: _descriptionController,
              maxLines: 3,
            ),
          ]),
          card([
            dateField(
              key: const Key('editEvent.startDate'),
              clearKey: const Key('editEvent.startDate.clear'),
              label: strings.startDate,
              value: _startDate,
              onChanged: (d) => setState(() => _startDate = d),
            ),
            dateField(
              key: const Key('editEvent.endDate'),
              clearKey: const Key('editEvent.endDate.clear'),
              label: strings.endDate,
              value: _endDate,
              error: _dateError,
              onChanged: (d) => setState(() => _endDate = d),
            ),
          ]),
          card([
            CpSwitchRow(
              key: const Key('editEvent.archive'),
              title: strings.archivedLabel,
              help: archived ? strings.archivedOn : strings.archivedOff,
              value: archived,
              onChanged: (value) => setState(() {
                _status = value
                    ? EventStatus.archived
                    : widget.initial.status == EventStatus.archived
                    ? widget.initial.restoredStatus(DateTime.now())
                    : widget.initial.status;
              }),
            ),
          ]),
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
                key: const Key('editEvent.save'),
                label: strings.saveChanges,
                onPressed: _submit,
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: strings.editTitle,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: navigator.canPop() ? () => navigator.maybePop() : null,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.sm,
          cp.space.lg,
          cp.space.xxl,
        ),
        child: ContentMaxWidth(
          key: const Key('editEvent.body.clamped'),
          maxWidth: cp.sizes.phoneColumn,
          child: body,
        ),
      ),
      bottomNavigationBar: saveBar,
    );
  }
}
