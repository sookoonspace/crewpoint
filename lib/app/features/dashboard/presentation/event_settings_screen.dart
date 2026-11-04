import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/create_event_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_status_label.dart';

/// Parses a positive whole number. Empty gives null, and anything else invalid
/// is reported by the field's validator.
int? _parseCount(String text) => int.tryParse(text.trim());

/// Splits comma-separated language codes.
List<String> _parseLanguages(String text) => text
    .split(',')
    .map((code) => code.trim())
    .where((code) => code.isNotEmpty)
    .toList();

final _languageCode = RegExp(r'^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$');
final _zoneName = RegExp(r'^[A-Za-z_]+(/[A-Za-z0-9_+-]+)*$');

class _VenueRow {
  _VenueRow({required this.id, String name = '', String address = ''})
    : name = TextEditingController(text: name),
      address = TextEditingController(text: address);

  final String id;
  final TextEditingController name;
  final TextEditingController address;

  void dispose() {
    name.dispose();
    address.dispose();
  }
}

/// Event settings, visible only to `event.manage`: time zone, venues, currency,
/// languages, capacity and member limit. Status, modules, labels and expense
/// access join this screen as they arrive.
class EventSettingsScreen extends ConsumerWidget {
  const EventSettingsScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final strings = context.strings.dashboard;
    if (uid == null || !event.canManage(uid)) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.settingsTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.lg,
              children: [
                Text(
                  strings.settingsNoAccess,
                  key: const Key('events.settings.noAccess'),
                  textAlign: TextAlign.center,
                ),
                OutlinedButton(
                  key: const Key('events.settings.back'),
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/dashboard/event/${event.id}'),
                  child: Text(strings.settingsBack),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _SettingsForm(event: event);
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.event});

  final EventModel event;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _timeZone;
  late final TextEditingController _languages;
  late final TextEditingController _capacity;
  late final TextEditingController _memberLimit;
  late final List<_VenueRow> _venues;
  late String _currency;
  late EventStatus _status;
  bool _dirty = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _timeZone = _tracked(event.timeZone);
    _languages = _tracked(event.languages.join(', '));
    _capacity = _tracked(event.capacity?.toString() ?? '');
    _memberLimit = _tracked(event.memberLimit?.toString() ?? '');
    _venues = [
      for (final venue in event.venues)
        _trackedVenue(
          _VenueRow(
            id: venue.id,
            name: venue.name,
            address: venue.address ?? '',
          ),
        ),
    ];
    _currency = event.currency;
    _status = event.status;
  }

  /// An archived event can only be restored.
  bool get _archived => widget.event.status == EventStatus.archived;

  TextEditingController _tracked(String text) =>
      TextEditingController(text: text)..addListener(_markDirty);

  _VenueRow _trackedVenue(_VenueRow row) {
    row.name.addListener(_markDirty);
    row.address.addListener(_markDirty);
    return row;
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _timeZone.dispose();
    _languages.dispose();
    _capacity.dispose();
    _memberLimit.dispose();
    for (final venue in _venues) {
      venue.dispose();
    }
    super.dispose();
  }

  void _addVenue() {
    setState(() {
      _venues.add(_trackedVenue(_VenueRow(id: const Uuid().v4())));
      _dirty = true;
    });
  }

  void _removeVenue(_VenueRow venue) {
    setState(() {
      _venues.remove(venue);
      _dirty = true;
    });
    venue.dispose();
  }

  String? _validateCount(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final count = _parseCount(text);
    if (count == null || count <= 0) {
      return context.strings.dashboard.settingsWholeNumber;
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final strings = context.strings.dashboard;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });

    final event = widget.event;
    // Currency goes first because it can be refused, and a refusal then leaves
    // everything as it was, with the form still filled in.
    if (!_archived && _currency != event.currency) {
      try {
        await ref.read(changeEventCurrencyCallProvider)(event.id, _currency);
      } catch (e) {
        if (!mounted) return;
        final locked =
            e is FirebaseFunctionsException && e.code == 'failed-precondition';
        setState(() {
          _saving = false;
          _error = locked
              ? strings.settingsCurrencyLocked
              : isConnectionFailure(e)
              ? strings.settingsNeedsConnection
              : strings.settingsFailed;
        });
        return;
      }
    }

    final capacity = _parseCount(_capacity.text);
    final memberLimit = _parseCount(_memberLimit.text);
    final result = await ref
        .read(eventRepositoryProvider)
        .saveConfiguration(
          previousStatus: event.status,
          event.copyWith(
            status: _status,
            timeZone: _timeZone.text.trim(),
            venues: [
              for (final venue in _venues)
                EventVenue(
                  id: venue.id,
                  name: venue.name.text.trim(),
                  address: venue.address.text.trim().isEmpty
                      ? null
                      : venue.address.text.trim(),
                ),
            ],
            languages: _parseLanguages(_languages.text),
            capacity: capacity,
            clearCapacity: capacity == null,
            memberLimit: memberLimit,
            clearMemberLimit: memberLimit == null,
          ),
        );
    if (!mounted) return;

    if (result == EventWriteResult.failed) {
      setState(() {
        _saving = false;
        _error = strings.settingsFailed;
      });
      return;
    }
    setState(() {
      _saving = false;
      _dirty = false;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result == EventWriteResult.saved
              ? strings.settingsSaved
              : strings.settingsPending,
        ),
      ),
    );
    if (context.canPop()) context.pop();
  }

  Future<void> _confirmLeave() async {
    final strings = context.strings.dashboard;
    final navigator = Navigator.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(strings.settingsDiscardTitle),
        content: Text(strings.settingsDiscardBody),
        actions: [
          TextButton(
            key: const Key('events.settings.keepEditing'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(strings.settingsKeepEditing),
          ),
          TextButton(
            key: const Key('events.settings.discard'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(strings.settingsDiscard),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _dirty = false);
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.dashboard;
    final theme = Theme.of(context);
    final event = widget.event;
    final expenses = ref.watch(expenseListProvider(event.id));
    final hasMoney = expenses.value?.isNotEmpty ?? false;
    // Until the list arrives the answer is unknown, and the server has the
    // final say either way.
    final currencyEnabled =
        expenses.hasValue && !hasMoney && !_saving && !_archived;
    final currencies = {
      ...CreateEventScreen.supportedCurrencies,
      event.currency,
    };

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(strings.settingsTitle), elevation: 0),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Breakpoints.screenHorizontalPadding(context),
            vertical: AppSpacing.xl,
          ),
          child: ContentMaxWidth(
            key: const Key('events.settings.body'),
            maxWidth: 560,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.lg,
                children: [
                  if (_archived)
                    Text(
                      strings.settingsArchivedNotice,
                      key: const Key('events.settings.archivedNotice'),
                    ),
                  DropdownButtonFormField<EventStatus>(
                    key: const Key('events.settings.status'),
                    initialValue: _status,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings.settingsStatus,
                      helperText:
                          event.canBeDraft || event.status == EventStatus.draft
                          ? null
                          : strings.settingsStatusDraftUnavailable,
                      helperMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final status in EventStatus.values)
                        DropdownMenuItem(
                          value: status,
                          enabled:
                              status != EventStatus.draft ||
                              event.canBeDraft ||
                              event.status == EventStatus.draft,
                          child: Text(eventStatusLabel(strings, status)),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _status = value;
                              _dirty = true;
                            });
                          },
                  ),
                  TextFormField(
                    key: const Key('events.settings.timeZone'),
                    enabled: !_archived,
                    controller: _timeZone,
                    decoration: InputDecoration(
                      labelText: strings.settingsTimeZone,
                      helperText: strings.settingsTimeZoneHelp,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        _zoneName.hasMatch(value?.trim() ?? '')
                        ? null
                        : strings.settingsTimeZoneInvalid,
                  ),
                  Text(
                    strings.settingsVenues,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (_venues.isEmpty)
                    Text(
                      strings.settingsVenuesEmpty,
                      key: const Key('events.settings.venuesEmpty'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  for (final (index, venue) in _venues.indexed)
                    _VenueFields(
                      key: ValueKey(venue.id),
                      enabled: !_archived,
                      index: index,
                      venue: venue,
                      onRemove: () => _removeVenue(venue),
                    ),
                  if (!_archived)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: const Key('events.settings.venue.add'),
                        onPressed: _addVenue,
                        icon: const Icon(Icons.add),
                        label: Text(strings.settingsVenueAdd),
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    key: const Key('events.settings.currency'),
                    initialValue: _currency,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings.settingsCurrency,
                      helperText: hasMoney
                          ? strings.settingsCurrencyLocked
                          : strings.settingsCurrencyHelp,
                      helperMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final code in currencies)
                        DropdownMenuItem(value: code, child: Text(code)),
                    ],
                    onChanged: currencyEnabled
                        ? (value) {
                            if (value == null) return;
                            setState(() {
                              _currency = value;
                              _dirty = true;
                            });
                          }
                        : null,
                  ),
                  TextFormField(
                    key: const Key('events.settings.languages'),
                    enabled: !_archived,
                    controller: _languages,
                    decoration: InputDecoration(
                      labelText: strings.settingsLanguages,
                      helperText: strings.settingsLanguagesHelp,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final codes = _parseLanguages(value ?? '');
                      return codes.isNotEmpty &&
                              codes.every(_languageCode.hasMatch)
                          ? null
                          : strings.settingsLanguagesInvalid;
                    },
                  ),
                  TextFormField(
                    key: const Key('events.settings.capacity'),
                    enabled: !_archived,
                    controller: _capacity,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.settingsCapacity,
                      helperText: strings.settingsCapacityCount(
                        event.memberIds.length,
                        event.capacity,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: _validateCount,
                  ),
                  TextFormField(
                    key: const Key('events.settings.memberLimit'),
                    enabled: !_archived,
                    controller: _memberLimit,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.settingsMemberLimit,
                      helperText: strings.settingsMemberLimitHelp,
                      helperMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    validator: _validateCount,
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      key: const Key('events.settings.error'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  PrimaryButton(
                    key: const Key('events.settings.save'),
                    label: strings.settingsSave,
                    isLoading: _saving,
                    onPressed: _save,
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

class _VenueFields extends StatelessWidget {
  const _VenueFields({
    super.key,
    required this.enabled,
    required this.index,
    required this.venue,
    required this.onRemove,
  });

  final bool enabled;
  final int index;
  final _VenueRow venue;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.dashboard;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Expanded(
          child: Column(
            spacing: AppSpacing.sm,
            children: [
              TextFormField(
                key: Key('events.settings.venue.$index.name'),
                enabled: enabled,
                controller: venue.name,
                decoration: InputDecoration(
                  labelText: strings.settingsVenueName,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? strings.settingsVenueNameRequired
                    : null,
              ),
              TextFormField(
                key: Key('events.settings.venue.$index.address'),
                enabled: enabled,
                controller: venue.address,
                decoration: InputDecoration(
                  labelText: strings.settingsVenueAddress,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: Key('events.settings.venue.$index.remove'),
          tooltip: strings.settingsVenueRemove,
          onPressed: enabled ? onRemove : null,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
