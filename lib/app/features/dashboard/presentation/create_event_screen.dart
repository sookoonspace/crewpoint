import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/form_card_shell.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key, this.defaultCurrency = 'USD'});

  final String defaultCurrency;

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
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  EventType _eventType = EventType.custom;
  DateTime? _startDate;
  late String _currency = widget.defaultCurrency;
  bool _isSubmitting = false;
  String? _errorMessage;

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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Capture the messenger and navigator BEFORE the await — pop()
    // tears down the route, after which `ScaffoldMessenger.of(context)`
    // would throw because the element has been deactivated.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      setState(() => _errorMessage = 'Sign-in required to create an event.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final description = _descriptionController.text.trim();
    final event = EventModel(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      description: description.isEmpty ? null : description,
      eventType: _eventType,
      creatorId: uid,
      startDate: _startDate,
      adminIds: [uid],
      memberIds: [uid],
      currency: _currency,
    );

    try {
      await ref.read(eventRepositoryProvider).createEvent(event);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Event created')));
    } catch (e, st) {
      log('createEvent failed', error: e, stackTrace: st, name: 'events');
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = "Couldn't create event — try again";
      });
    }
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
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.xl,
        ),
        child: ContentMaxWidth(
          key: const Key('createEvent.body.clamped'),
          maxWidth: 480,
          child: FormCardShell(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        onSelected: _isSubmitting
                            ? null
                            : (_) => setState(() => _eventType = type),
                        selectedColor: AppColors.sage,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.white
                              : AppColors.charcoal,
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
                    key: const Key('createEvent.title'),
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
                    key: const Key('createEvent.description'),
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
                            onPressed: _isSubmitting
                                ? null
                                : () => setState(() => _startDate = null),
                          )
                        : null,
                    onTap: _isSubmitting ? null : _pickDate,
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
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _currency = value);
                            }
                          },
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      key: const Key('createEvent.error'),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.terracotta.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.terracotta),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.terracotta,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.terracotta,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  PrimaryButton(
                    key: const Key('createEvent.submit'),
                    label: 'Create Event',
                    onPressed: _isSubmitting ? null : _submit,
                    isLoading: _isSubmitting,
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
