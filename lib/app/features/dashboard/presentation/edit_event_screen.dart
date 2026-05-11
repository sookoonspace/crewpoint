import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/form_card_shell.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Edit screen for an existing event. Pure presentation — emits the
/// updated [EventModel] via `onSubmit`. Currency is intentionally NOT
/// editable here (data-integrity boundary; see spec `<boundaries>`).
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
  late EventType _eventType;
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
    _eventType = widget.initial.eventType;
    _startDate = widget.initial.startDate;
    _endDate = widget.initial.endDate;
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

  /// Returns null when the range is valid; error message otherwise.
  String? _validateDateRange(DateTime? start, DateTime? end) {
    if (end == null || start == null) return null;
    if (end.isBefore(start)) return 'End date must be on or after start date';
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final dateError = _validateDateRange(_startDate, _endDate);
    if (dateError != null) {
      setState(() => _dateError = dateError);
      return;
    }
    setState(() => _dateError = null);

    final updated = widget.initial.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      eventType: _eventType,
      startDate: _startDate,
      endDate: _endDate,
      clearStartDate: _startDate == null,
      clearEndDate: _endDate == null,
      status: _status,
    );
    widget.onSubmit?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Edit Event'),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.xl,
        ),
        child: ContentMaxWidth(
          key: const Key('editEvent.body.clamped'),
          maxWidth: 480,
          child: FormCardShell(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: .start,
                spacing: AppSpacing.lg,
                children: [
                  // Event type chips
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: EventType.values.map((type) {
                      final isSelected = _eventType == type;
                      return ChoiceChip(
                        label: Text(type.label),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _eventType = type),
                        selectedColor: AppColors.sage,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.white
                              : AppColors.charcoal,
                        ),
                      );
                    }).toList(),
                  ),
                  CustomTextField(
                    key: const Key('editEvent.title'),
                    hintText: 'Title',
                    controller: _titleController,
                    prefixIcon: const Icon(Icons.event),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      if (value.length > 200) {
                        return 'Title must be under 200 characters';
                      }
                      return null;
                    },
                  ),
                  CustomTextField(
                    key: const Key('editEvent.description'),
                    hintText: 'Description (optional)',
                    controller: _descriptionController,
                    maxLines: 3,
                    prefixIcon: const Icon(Icons.description_outlined),
                  ),
                  ListTile(
                    key: const Key('editEvent.startDate'),
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Start Date'),
                    subtitle: Text(
                      _startDate != null ? df.format(_startDate!) : 'Optional',
                    ),
                    trailing: _startDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _startDate = null),
                          )
                        : null,
                    onTap: () async {
                      final picked = await _pickDate(_startDate);
                      if (picked != null) {
                        setState(() => _startDate = picked);
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.lightGrey),
                    ),
                  ),
                  ListTile(
                    key: const Key('editEvent.endDate'),
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('End Date'),
                    subtitle: Text(
                      _endDate != null ? df.format(_endDate!) : 'Optional',
                    ),
                    trailing: _endDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _endDate = null),
                          )
                        : null,
                    onTap: () async {
                      final picked = await _pickDate(_endDate);
                      if (picked != null) {
                        setState(() => _endDate = picked);
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.lightGrey),
                    ),
                  ),
                  if (_dateError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        _dateError!,
                        style: const TextStyle(color: AppColors.terracotta),
                      ),
                    ),
                  SwitchListTile(
                    key: const Key('editEvent.archive'),
                    title: const Text('Archived'),
                    subtitle: Text(
                      _status == EventStatus.archived
                          ? 'Event is read-only'
                          : 'Active',
                    ),
                    value: _status == EventStatus.archived,
                    onChanged: (archived) => setState(() {
                      _status = archived
                          ? EventStatus.archived
                          : EventStatus.active;
                    }),
                    activeThumbColor: AppColors.sage,
                  ),
                  PrimaryButton(
                    key: const Key('editEvent.save'),
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
