import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:uuid/uuid.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({
    super.key,
    this.defaultCurrency = 'USD',
    this.onSubmit,
  });

  final String defaultCurrency;
  final ValueChanged<EventModel>? onSubmit;

  /// V1 supported currencies. Display-only — no FX conversion in V1.
  static const List<String> supportedCurrencies = [
    'USD',
    'EUR',
    'GBP',
    'CAD',
    'AUD',
    'JPY',
    'INR',
  ];

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  EventType _eventType = EventType.custom;
  DateTime? _startDate;
  late String _currency = widget.defaultCurrency;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final event = EventModel(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      eventType: _eventType,
      creatorId: '', // Set by caller
      startDate: _startDate,
      adminIds: const [],
      memberIds: const [],
      currency: _currency,
    );

    widget.onSubmit?.call(event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: .start,
            spacing: AppSpacing.lg,
            children: [
              // Event Type
              Text(
                'Event Type',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.charcoal),
              ),
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
                      color: isSelected ? AppColors.white : AppColors.charcoal,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Title
              Text(
                'Title',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.charcoal),
              ),
              CustomTextField(
                hintText: 'What are you planning?',
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

              // Description
              Text(
                'Description',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.charcoal),
              ),
              CustomTextField(
                hintText: 'Details, location, notes... (optional)',
                controller: _descriptionController,
                maxLines: 3,
                prefixIcon: const Icon(Icons.description_outlined),
              ),

              // Start Date (optional)
              ListTile(
                leading: const Icon(
                  Icons.calendar_today,
                  color: AppColors.darkGrey,
                ),
                title: const Text('Start Date'),
                subtitle: Text(
                  _startDate != null
                      ? _startDate.toString().split(' ')[0]
                      : 'Optional — tap to set',
                  style: TextStyle(
                    color: _startDate != null
                        ? AppColors.charcoal
                        : AppColors.mediumGrey,
                  ),
                ),
                trailing: _startDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _startDate = null),
                      )
                    : null,
                onTap: _pickDate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.lightGrey),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Currency (immutable after creation)
              Text(
                'Currency',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.charcoal),
              ),
              DropdownButtonFormField<String>(
                key: const Key('events.create.currency'),
                initialValue: _currency,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                  helperText: 'Cannot be changed after creating the event.',
                ),
                items: [
                  for (final code in CreateEventScreen.supportedCurrencies)
                    DropdownMenuItem(value: code, child: Text(code)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _currency = value);
                },
              ),

              const SizedBox(height: AppSpacing.md),

              PrimaryButton(label: 'Create Event', onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
