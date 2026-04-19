import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:uuid/uuid.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key, this.onSubmit});

  final ValueChanged<EventModel>? onSubmit;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _startDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
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
      creatorId: '', // Set by caller
      startDate: _startDate,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
    );

    widget.onSubmit?.call(event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            spacing: AppSpacing.lg,
            children: [
              CustomTextField(
                hintText: 'Event Title',
                controller: _titleController,
                prefixIcon: const Icon(Icons.event),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              CustomTextField(
                hintText: 'Description (optional)',
                controller: _descriptionController,
                maxLines: 3,
                prefixIcon: const Icon(Icons.description),
              ),
              CustomTextField(
                hintText: 'Location (optional)',
                controller: _locationController,
                prefixIcon: const Icon(Icons.location_on),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Start Date'),
                subtitle: Text(_startDate.toString().split(' ')[0]),
                onTap: _pickDate,
              ),
              PrimaryButton(label: 'Create Event', onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
