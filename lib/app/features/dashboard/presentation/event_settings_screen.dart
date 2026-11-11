import 'package:cloud_functions/cloud_functions.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart'
    show isWebLink;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
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

class _VenueRow {
  _VenueRow({
    required this.id,
    String name = '',
    String address = '',
    String mapUrl = '',
    String directions = '',
  }) : name = TextEditingController(text: name),
       address = TextEditingController(text: address),
       mapUrl = TextEditingController(text: mapUrl),
       directions = TextEditingController(text: directions);

  final String id;
  final TextEditingController name;
  final TextEditingController address;
  final TextEditingController mapUrl;
  final TextEditingController directions;

  List<TextEditingController> get boxes => [name, address, mapUrl, directions];

  void dispose() {
    for (final box in boxes) {
      box.dispose();
    }
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

  /// One box for each form of each concept, keyed `concept.form`.
  late final Map<String, TextEditingController> _labels;
  late String _currency;
  late EventStatus _status;
  late AttendancePolicy _policy;
  late final Map<String, bool> _modules;
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
            mapUrl: venue.mapUrl ?? '',
            directions: venue.directions ?? '',
          ),
        ),
    ];
    _currency = event.currency;
    _status = event.status;
    _policy = event.attendancePolicy;
    _modules = {
      for (final module in EventModel.defaultModules.keys)
        module: event.isModuleOn(module),
    };
    _labels = {
      for (final concept in LabelDefaults.current.concepts)
        for (final form in const ['one', 'other'])
          '$concept.$form': _tracked(
            event.words.customForm(concept, form) ?? '',
          ),
    };
  }

  /// An archived event can only be restored.
  bool get _archived => widget.event.status == EventStatus.archived;

  TextEditingController _tracked(String text) =>
      TextEditingController(text: text)..addListener(_markDirty);

  _VenueRow _trackedVenue(_VenueRow row) {
    for (final box in row.boxes) {
      box.addListener(_markDirty);
    }
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
    for (final box in _labels.values) {
      box.dispose();
    }
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

  /// Only what the organizer typed. Empty boxes keep the default, so a default
  /// that later improves still reaches this event.
  Map<String, dynamic> _enteredLabels() => {
    for (final concept in LabelDefaults.current.concepts)
      if (_labels['$concept.one']!.text.trim().isNotEmpty ||
          _labels['$concept.other']!.text.trim().isNotEmpty)
        concept: {
          for (final form in const ['one', 'other'])
            if (_labels['$concept.$form']!.text.trim().isNotEmpty)
              form: _labels['$concept.$form']!.text.trim(),
        },
  };

  static String? _orNull(TextEditingController box) =>
      box.text.trim().isEmpty ? null : box.text.trim();

  Future<void> _pickTimeZone() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => const _TimeZonePicker(),
    );
    if (picked != null) _timeZone.text = picked;
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
          attendancePolicy: _policy,
          event.copyWith(
            status: _status,
            timeZone: _timeZone.text.trim(),
            venues: [
              for (final venue in _venues)
                EventVenue(
                  id: venue.id,
                  name: venue.name.text.trim(),
                  address: _orNull(venue.address),
                  mapUrl: _orNull(venue.mapUrl),
                  directions: _orNull(venue.directions),
                ),
            ],
            languages: _parseLanguages(_languages.text),
            labels: _enteredLabels(),
            modules: _modules,
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
    // Only counts.read may read the counts (Req 52).
    final readsCounts = event.can(
      ref.watch(currentUserIdProvider) ?? '',
      'counts.read',
    );
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
                    readOnly: true,
                    onTap: _pickTimeZone,
                    decoration: InputDecoration(
                      labelText: strings.settingsTimeZone,
                      helperText: strings.settingsTimeZoneHelp,
                      helperMaxLines: 3,
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                      border: const OutlineInputBorder(),
                    ),
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
                      // Capacity counts everyone attending, with or without
                      // an account (Req 18b).
                      // From the counts when they exist (Req 52), so the
                      // number matches the counts screen.
                      helperText: strings.settingsCapacityCount(
                        (readsCounts
                                ? ref
                                      .watch(eventStatsProvider(event.id))
                                      .value
                                      ?.event
                                      .total
                                : null) ??
                            ref
                                .watch(participantCountProvider(event.id))
                                .value ??
                            event.memberCount,
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
                  DropdownButtonFormField<AttendancePolicy>(
                    key: const Key('events.settings.attendancePolicy'),
                    initialValue: _policy,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.strings.agenda.policyLabel,
                      helperText: context.strings.agenda.policyHelp(
                        _policy.name,
                      ),
                      helperMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in AttendancePolicy.values)
                        DropdownMenuItem(
                          value: p,
                          child: Text(context.strings.agenda.policy(p.name)),
                        ),
                    ],
                    onChanged: _archived || _saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _policy = value;
                              _dirty = true;
                            });
                          },
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        strings.settingsModules,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        strings.settingsModulesHelp,
                        style: theme.textTheme.bodySmall,
                      ),
                      for (final (module, label) in [
                        ('chat', strings.moduleChat),
                        ('budget', strings.moduleBudget),
                        ('tasks', strings.moduleTasks),
                        ('schedule', context.strings.schedule.title),
                      ])
                        SwitchListTile(
                          key: Key('events.settings.module.$module'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(label),
                          value: _modules[module]!,
                          onChanged: _archived
                              ? null
                              : (on) => setState(() {
                                  _modules[module] = on;
                                  _dirty = true;
                                }),
                        ),
                    ],
                  ),
                  ListTile(
                    key: const Key('events.settings.fields'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.actionEdit),
                    title: Text(context.strings.fields.settingsEntry),
                    subtitle: Text(context.strings.fields.settingsEntryHelp),
                    trailing: const Icon(AppIcons.chevronRight),
                    onTap: () => context.push(
                      '/dashboard/event/${widget.event.id}/fields',
                    ),
                  ),
                  ListTile(
                    key: const Key('events.settings.expenseAccess'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.lock),
                    title: Text(context.strings.expenseAccess.title),
                    subtitle: Text(
                      context.strings.expenseAccess.summary(
                        widget.event.expenseAccess.mode,
                        includesEveryone:
                            widget.event.expenseAccess.includeNonContributors,
                      ),
                    ),
                    trailing: const Icon(AppIcons.chevronRight),
                    onTap: () => context.push(
                      '/dashboard/event/${widget.event.id}/settings/expenses',
                    ),
                  ),
                  ExpansionTile(
                    key: const Key('events.settings.labels'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(strings.settingsLabels),
                    subtitle: Text(strings.settingsLabelsHelp),
                    childrenPadding: const EdgeInsets.only(
                      bottom: AppSpacing.md,
                    ),
                    children: [
                      for (final concept in LabelDefaults.current.concepts)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: _LabelFields(
                            concept: concept,
                            enabled: !_archived,
                            one: _labels['$concept.one']!,
                            other: _labels['$concept.other']!,
                          ),
                        ),
                    ],
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

class _TimeZonePicker extends StatefulWidget {
  const _TimeZonePicker();

  @override
  State<_TimeZonePicker> createState() => _TimeZonePickerState();
}

class _TimeZonePickerState extends State<_TimeZonePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.dashboard;
    final query = _query.toLowerCase().replaceAll(' ', '_');
    final zones = allTimeZones
        .where((zone) => zone.toLowerCase().contains(query))
        .toList();
    return AlertDialog(
      title: Text(strings.settingsTimeZone),
      content: SizedBox(
        width: 420,
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          spacing: AppSpacing.md,
          children: [
            TextField(
              key: const Key('events.settings.timeZone.search'),
              autofocus: true,
              decoration: InputDecoration(
                hintText: strings.settingsTimeZoneSearch,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            Expanded(
              child: zones.isEmpty
                  ? Center(child: Text(strings.settingsTimeZoneNone))
                  : ListView.builder(
                      itemCount: zones.length,
                      itemBuilder: (_, index) => ListTile(
                        key: Key('events.settings.timeZone.${zones[index]}'),
                        title: Text(zones[index]),
                        onTap: () => Navigator.of(context).pop(zones[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelFields extends StatelessWidget {
  const _LabelFields({
    required this.concept,
    required this.enabled,
    required this.one,
    required this.other,
  });

  final String concept;
  final bool enabled;
  final TextEditingController one;
  final TextEditingController other;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.dashboard;
    final defaults = LabelDefaults.current;
    return Column(
      spacing: AppSpacing.sm,
      children: [
        TextFormField(
          key: Key('events.settings.label.$concept.one'),
          enabled: enabled,
          controller: one,
          decoration: InputDecoration(
            labelText: strings.settingsLabelOne(defaults.form(concept, 'one')),
            border: const OutlineInputBorder(),
          ),
        ),
        TextFormField(
          key: Key('events.settings.label.$concept.other'),
          enabled: enabled,
          controller: other,
          decoration: InputDecoration(
            labelText: strings.settingsLabelOther(
              defaults.form(concept, 'other'),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
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
    final schedule = context.strings.schedule;
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
                  helperText: schedule.venueAddressHelp,
                  border: const OutlineInputBorder(),
                ),
              ),
              TextFormField(
                key: Key('events.settings.venue.$index.mapUrl'),
                enabled: enabled,
                controller: venue.mapUrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: schedule.venueMapLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return text.isEmpty || isWebLink(text)
                      ? null
                      : schedule.venueMapInvalid;
                },
              ),
              TextFormField(
                key: Key('events.settings.venue.$index.directions'),
                enabled: enabled,
                controller: venue.directions,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: schedule.venueDirectionsLabel,
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
