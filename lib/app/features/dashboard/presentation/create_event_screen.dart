import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_sizes.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/form_card_shell.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/add_member_sheet.dart';

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
  DateTime? _startDate;
  late String _currency = widget.defaultCurrency;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _needsConnection = false;

  /// Kept across retries, so a create that reached the server is not repeated.
  final String _eventId = const Uuid().v4();

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
      _needsConnection = false;
    });

    final repository = ref.read(eventRepositoryProvider);
    final strings = context.strings.dashboard;
    // The event starts in this person's zone. An organizer can change it.
    final timeZone = await ref.read(deviceTimezoneProvider).getLocalTimezone();
    final description = _descriptionController.text.trim();
    final event = EventModel(
      id: _eventId,
      title: _titleController.text.trim(),
      description: description.isEmpty ? null : description,
      creatorId: uid,
      startDate: _startDate,
      adminIds: [uid],
      memberIds: [uid],
      currency: _currency,
      timeZone: timeZone,
    );

    try {
      await repository.createEvent(event);
      if (!mounted) return;
      navigator.pop();
      // 6s gives the user time to read "Event created" and tap "Share
      // invite" without rushing them; long enough to react, short enough
      // not to loiter on the dashboard. Material default is ~4s.
      // Use navigator.context (not messenger.context) — the ScaffoldMessenger
      // sits ABOVE the Navigator in the widget tree, so its context has no
      // Navigator ancestor and showModalBottomSheet throws "Navigator
      // operation requested with a context that does not include a
      // Navigator." The Navigator's own context resolves cleanly.
      messenger.showSnackBar(
        SnackBar(
          content: Text(strings.draftCreated),
          action: SnackBarAction(
            label: strings.publishAndInvite,
            onPressed: () async {
              final result = await repository.setStatus(
                event.id,
                EventStatus.published,
              );
              if (result == EventWriteResult.saved) {
                if (!navigator.mounted) return;
                await AddMemberSheet.show(
                  context: navigator.context,
                  eventId: event.id,
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(content: Text(strings.publishFailed)),
                );
              }
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e, st) {
      log('createEvent failed', error: e, stackTrace: st, name: 'events');
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _needsConnection = isConnectionFailure(e);
        _errorMessage = _needsConnection
            ? context.strings.dashboard.createEventNeedsConnection
            : "Couldn't create event — try again";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event'), elevation: 0),
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
                  const SizedBox(height: AppSpacing.sm),

                  // Title
                  Text(
                    'Title',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  CustomTextField(
                    key: const Key('createEvent.title'),
                    hintText: 'What are you planning?',
                    controller: _titleController,
                    prefixIcon: const Icon(AppIcons.event),
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
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  CustomTextField(
                    key: const Key('createEvent.description'),
                    hintText: 'Details, location, notes... (optional)',
                    controller: _descriptionController,
                    maxLines: 3,
                    prefixIcon: const Icon(AppIcons.markdown),
                  ),

                  // Start Date (optional)
                  ListTile(
                    leading: Icon(
                      AppIcons.calendar,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: const Text('Start Date'),
                    subtitle: Text(
                      _startDate != null
                          ? _startDate.toString().split(' ')[0]
                          : 'Optional — tap to set',
                      style: TextStyle(
                        color: _startDate != null
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: _startDate != null
                        ? IconButton(
                            icon: const Icon(AppIcons.actionClear, size: 18),
                            onPressed: _isSubmitting
                                ? null
                                : () => setState(() => _startDate = null),
                          )
                        : null,
                    onTap: _isSubmitting ? null : _pickDate,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Currency (immutable after creation)
                  Text(
                    'Currency',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    key: const Key('events.create.currency'),
                    initialValue: _currency,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(AppIcons.currency),
                      border: OutlineInputBorder(),
                      helperText:
                          'Can be changed in settings until money is recorded.',
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
                            AppIcons.statusError,
                            color: AppColors.terracotta,
                            size: AppSizes.iconMd,
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
                    label: _needsConnection
                        ? context.strings.dashboard.createEventRetry
                        : 'Create Event',
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
