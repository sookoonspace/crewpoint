import 'package:cloud_functions/cloud_functions.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_cover_service.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_cover.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart'
    show isWebLink;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/create_event_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_status_label.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

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
      return AdminScaffold(
        title: strings.settingsTitle,
        body: CpEmptyState(
          key: const Key('events.settings.noAccess'),
          icon: CpIcons.lock,
          title: strings.settingsNoAccess,
          actionLabel: strings.settingsBack,
          actionKey: const Key('events.settings.back'),
          onAction: () => context.canPop()
              ? context.pop()
              : context.go('/dashboard/event/${event.id}'),
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
    if (picked != null) setState(() => _timeZone.text = picked);
  }

  /// A sheet of [choices] keyed `events.settings.$keyName.$id`, the current
  /// one ticked; a choice with no tap is shown but cannot be picked.
  Future<T?> _pick<T>({
    required String title,
    required String keyName,
    required T current,
    required List<(T value, String id, String label, bool enabled)> choices,
  }) {
    final cp = context.cp;
    return showCpSheet<T>(
      context: context,
      title: title,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final (value, id, label, enabled) in choices)
              CpListRow(
                key: Key('events.settings.$keyName.$id'),
                title: label,
                trailing: value == current
                    ? Icon(
                        CpIcons.statusDone,
                        size: cp.sizes.iconMd,
                        color: cp.colors.accent,
                      )
                    : const SizedBox.shrink(),
                onTap: enabled ? () => Navigator.of(sheet).pop(value) : null,
              ),
          ],
        ),
      ),
    );
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
      builder: (dialog) => CpDialog(
        title: strings.settingsDiscardTitle,
        message: strings.settingsDiscardBody,
        actions: [
          CpButton.text(
            key: const Key('events.settings.keepEditing'),
            label: strings.settingsKeepEditing,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          CpButton.destructive(
            key: const Key('events.settings.discard'),
            label: strings.settingsDiscard,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _dirty = false);
      navigator.pop();
    }
  }

  /// Who can register, read as the Registration screen reads it (#239).
  String _registrationMode(BuildContext context) {
    final template = ref
        .watch(templateCatalogueProvider)
        .value
        ?.where((t) => t.id == widget.event.templateId)
        .firstOrNull;
    final settings = RegistrationSettings.fromMaps(
      widget.event.settings['registration'],
      template?.registration,
    );
    final strings = context.strings.registrationSettings;
    return settings.mode == RegistrationMode.open
        ? strings.modeOpen
        : strings.modeInvited;
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.dashboard;
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
    final canDraft = event.canBeDraft || event.status == EventStatus.draft;
    final agenda = context.strings.agenda;

    Widget card(List<Widget> children) => CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: children,
      ),
    );

    Widget link({
      required String key,
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) => CpListRow(
      key: Key('events.settings.$key'),
      leading: Icon(icon, size: cp.sizes.iconMd, color: cp.colors.accent),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: AdminScaffold(
        title: strings.settingsTitle,
        bottom: AdminSaveBar(
          child: CpButton(
            key: const Key('events.settings.save'),
            label: strings.settingsSave,
            busy: _saving,
            onPressed: _save,
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            cp.space.lg,
            cp.space.sm,
            cp.space.lg,
            cp.space.xxl,
          ),
          child: ContentMaxWidth(
            key: const Key('events.settings.body'),
            maxWidth: cp.sizes.phoneColumn,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: cp.space.lg,
                children: [
                  if (_archived)
                    AdminNote(
                      strings.settingsArchivedNotice,
                      key: const Key('events.settings.archivedNotice'),
                      icon: CpIcons.lock,
                    ),
                  if (!_archived) _CoverSection(event: event),
                  CpSectionHeader(title: strings.settingsEventHeading),
                  card([
                    CpSelectField(
                      fieldKey: const Key('events.settings.status'),
                      label: strings.settingsStatus,
                      value: eventStatusLabel(strings, _status),
                      help: canDraft
                          ? null
                          : strings.settingsStatusDraftUnavailable,
                      onTap: _saving
                          ? null
                          : () async {
                              final picked = await _pick<EventStatus>(
                                title: strings.settingsStatus,
                                keyName: 'status',
                                current: _status,
                                choices: [
                                  for (final status in EventStatus.values)
                                    (
                                      status,
                                      status.name,
                                      eventStatusLabel(strings, status),
                                      status != EventStatus.draft || canDraft,
                                    ),
                                ],
                              );
                              if (picked != null && mounted) {
                                setState(() {
                                  _status = picked;
                                  _dirty = true;
                                });
                              }
                            },
                    ),
                    CpSelectField(
                      fieldKey: const Key('events.settings.timeZone'),
                      label: strings.settingsTimeZone,
                      value: _timeZone.text,
                      help: strings.settingsTimeZoneHelp,
                      leadingIcon: CpIcons.schedule,
                      onTap: _archived ? null : _pickTimeZone,
                    ),
                    CpSelectField(
                      fieldKey: const Key('events.settings.currency'),
                      label: strings.settingsCurrency,
                      value: _currency,
                      help: hasMoney
                          ? strings.settingsCurrencyLocked
                          : strings.settingsCurrencyHelp,
                      onTap: currencyEnabled
                          ? () async {
                              final picked = await _pick<String>(
                                title: strings.settingsCurrency,
                                keyName: 'currency',
                                current: _currency,
                                choices: [
                                  for (final code in currencies)
                                    (code, code, code, true),
                                ],
                              );
                              if (picked != null && mounted) {
                                setState(() {
                                  _currency = picked;
                                  _dirty = true;
                                });
                              }
                            }
                          : null,
                    ),
                    CpTextField(
                      fieldKey: const Key('events.settings.languages'),
                      label: strings.settingsLanguages,
                      help: strings.settingsLanguagesHelp,
                      enabled: !_archived,
                      controller: _languages,
                      validator: (value) {
                        final codes = _parseLanguages(value ?? '');
                        return codes.isNotEmpty &&
                                codes.every(_languageCode.hasMatch)
                            ? null
                            : strings.settingsLanguagesInvalid;
                      },
                    ),
                  ]),
                  CpSectionHeader(title: strings.settingsVenues),
                  if (_venues.isEmpty)
                    AdminNote(
                      strings.settingsVenuesEmpty,
                      key: const Key('events.settings.venuesEmpty'),
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
                      child: CpButton.secondary(
                        key: const Key('events.settings.venue.add'),
                        icon: CpIcons.actionAdd,
                        label: strings.settingsVenueAdd,
                        onPressed: _addVenue,
                      ),
                    ),
                  CpSectionHeader(title: strings.settingsAttendanceHeading),
                  card([
                    CpTextField(
                      fieldKey: const Key('events.settings.capacity'),
                      label: strings.settingsCapacity,
                      enabled: !_archived,
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      // Capacity counts everyone attending, with or without
                      // an account (Req 18b). From the counts when they
                      // exist (Req 52), so the number matches the counts
                      // screen.
                      help: strings.settingsCapacityCount(
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
                      validator: _validateCount,
                    ),
                    CpTextField(
                      fieldKey: const Key('events.settings.memberLimit'),
                      label: strings.settingsMemberLimit,
                      help: strings.settingsMemberLimitHelp,
                      enabled: !_archived,
                      controller: _memberLimit,
                      keyboardType: TextInputType.number,
                      validator: _validateCount,
                    ),
                    CpSelectField(
                      fieldKey: const Key('events.settings.attendancePolicy'),
                      label: agenda.policyLabel,
                      value: agenda.policy(_policy.name),
                      help: agenda.policyHelp(_policy.name),
                      onTap: _archived || _saving
                          ? null
                          : () async {
                              final picked = await _pick<AttendancePolicy>(
                                title: agenda.policyLabel,
                                keyName: 'attendancePolicy',
                                current: _policy,
                                choices: [
                                  for (final p in AttendancePolicy.values)
                                    (p, p.name, agenda.policy(p.name), true),
                                ],
                              );
                              if (picked != null && mounted) {
                                setState(() {
                                  _policy = picked;
                                  _dirty = true;
                                });
                              }
                            },
                    ),
                  ]),
                  CpSectionHeader(title: strings.settingsModules),
                  AdminNote(strings.settingsModulesHelp),
                  CpCard(
                    padding: EdgeInsets.symmetric(
                      horizontal: cp.space.lg,
                      vertical: cp.space.xs,
                    ),
                    child: Column(
                      children: [
                        for (final (module, label) in [
                          ('chat', strings.moduleChat),
                          ('budget', strings.moduleBudget),
                          ('tasks', strings.moduleTasks),
                          ('schedule', context.strings.schedule.title),
                        ])
                          CpSwitchRow(
                            key: Key('events.settings.module.$module'),
                            title: label,
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
                  ),
                  CpSectionHeader(title: strings.settingsMoreHeading),
                  CpCard(
                    child: CpRowGroup(
                      children: [
                        link(
                          key: 'setup',
                          icon: CpIcons.statusDoneOutline,
                          title: context.strings.templates.setupEntry,
                          subtitle: context.strings.templates.setupEntryHelp,
                          onTap: () => context.push(
                            '/dashboard/event/${widget.event.id}/setup',
                          ),
                        ),
                        link(
                          key: 'saveTemplate',
                          icon: CpIcons.actionCopy,
                          title: context.strings.templates.saveAsTemplate,
                          subtitle:
                              context.strings.templates.saveAsTemplateHelp,
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (_) => _SaveTemplateDialog(
                              eventId: widget.event.id,
                              initialName: widget.event.title,
                            ),
                          ),
                        ),
                        link(
                          key: 'fields',
                          icon: CpIcons.actionEdit,
                          title: context.strings.fields.settingsEntry,
                          subtitle: context.strings.fields.settingsEntryHelp,
                          onTap: () => context.push(
                            '/dashboard/event/${widget.event.id}/fields',
                          ),
                        ),
                        link(
                          key: 'registration',
                          icon: CpIcons.registration,
                          title: widget.event.words.one('registration'),
                          subtitle: _registrationMode(context),
                          onTap: () => context.push(
                            '/dashboard/event/${widget.event.id}/settings/registration',
                          ),
                        ),
                        link(
                          key: 'expenseAccess',
                          icon: CpIcons.lock,
                          title: context.strings.expenseAccess.title,
                          subtitle: context.strings.expenseAccess.summary(
                            widget.event.expenseAccess.mode,
                            includesEveryone: widget
                                .event
                                .expenseAccess
                                .includeNonContributors,
                          ),
                          onTap: () => context.push(
                            '/dashboard/event/${widget.event.id}/settings/expenses',
                          ),
                        ),
                      ],
                    ),
                  ),
                  CpCard(
                    child: Theme(
                      // No lines above and below the open section.
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: cp.colors.surface),
                      child: ExpansionTile(
                        key: const Key('events.settings.labels'),
                        tilePadding: EdgeInsets.symmetric(
                          horizontal: cp.space.lg,
                        ),
                        iconColor: cp.colors.textMuted,
                        collapsedIconColor: cp.colors.textMuted,
                        title: Text(
                          strings.settingsLabels,
                          style: cp.type.titleSmall.copyWith(
                            color: cp.colors.text,
                          ),
                        ),
                        subtitle: Text(
                          strings.settingsLabelsHelp,
                          style: cp.type.bodySmall.copyWith(
                            color: cp.colors.textMuted,
                          ),
                        ),
                        childrenPadding: EdgeInsets.fromLTRB(
                          cp.space.lg,
                          0,
                          cp.space.lg,
                          cp.space.lg,
                        ),
                        children: [
                          for (final concept in LabelDefaults.current.concepts)
                            Padding(
                              padding: EdgeInsets.only(top: cp.space.md),
                              child: _LabelFields(
                                concept: concept,
                                enabled: !_archived,
                                one: _labels['$concept.one']!,
                                other: _labels['$concept.other']!,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null)
                    KeyedSubtree(
                      key: const Key('events.settings.error'),
                      child: CpFieldError(_error!),
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
    final cp = context.cp;
    final strings = context.strings.dashboard;
    final query = _query.toLowerCase().replaceAll(' ', '_');
    final zones = allTimeZones
        .where((zone) => zone.toLowerCase().contains(query))
        .toList();
    return CpDialog(
      title: strings.settingsTimeZone,
      content: SizedBox(
        width: cp.sizes.listPane,
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          spacing: cp.space.md,
          children: [
            CpSearchField(
              fieldKey: const Key('events.settings.timeZone.search'),
              hint: strings.settingsTimeZoneSearch,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
            ),
            Expanded(
              child: zones.isEmpty
                  ? Center(
                      child: Text(
                        strings.settingsTimeZoneNone,
                        style: cp.type.bodyMedium.copyWith(
                          color: cp.colors.textMuted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: zones.length,
                      itemBuilder: (_, index) => CpListRow(
                        key: Key('events.settings.timeZone.${zones[index]}'),
                        title: zones[index],
                        trailing: const SizedBox.shrink(),
                        onTap: () => Navigator.of(context).pop(zones[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: const [],
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
    final cp = context.cp;
    final strings = context.strings.dashboard;
    final defaults = LabelDefaults.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.sm,
      children: [
        CpTextField(
          fieldKey: Key('events.settings.label.$concept.one'),
          label: strings.settingsLabelOne(defaults.form(concept, 'one')),
          enabled: enabled,
          controller: one,
        ),
        CpTextField(
          fieldKey: Key('events.settings.label.$concept.other'),
          label: strings.settingsLabelOther(defaults.form(concept, 'other')),
          enabled: enabled,
          controller: other,
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
    final cp = context.cp;
    final strings = context.strings.dashboard;
    final schedule = context.strings.schedule;
    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          Row(
            children: [
              Icon(
                CpIcons.place,
                size: cp.sizes.iconMd,
                color: cp.colors.accent,
              ),
              SizedBox(width: cp.space.sm),
              Expanded(
                // Follows the name as it is typed.
                child: ListenableBuilder(
                  listenable: venue.name,
                  builder: (context, _) => Text(
                    venue.name.text.trim().isEmpty
                        ? strings.settingsVenueName
                        : venue.name.text.trim(),
                    style: cp.type.titleSmall.copyWith(color: cp.colors.text),
                  ),
                ),
              ),
              IconButton(
                key: Key('events.settings.venue.$index.remove'),
                tooltip: strings.settingsVenueRemove,
                onPressed: enabled ? onRemove : null,
                icon: Icon(
                  CpIcons.actionDelete,
                  size: cp.sizes.iconMd,
                  color: cp.colors.textMuted,
                ),
              ),
            ],
          ),
          CpTextField(
            fieldKey: Key('events.settings.venue.$index.name'),
            label: strings.settingsVenueName,
            required: true,
            enabled: enabled,
            controller: venue.name,
            validator: (value) => (value?.trim().isEmpty ?? true)
                ? strings.settingsVenueNameRequired
                : null,
          ),
          CpTextField(
            fieldKey: Key('events.settings.venue.$index.address'),
            label: strings.settingsVenueAddress,
            help: schedule.venueAddressHelp,
            enabled: enabled,
            controller: venue.address,
          ),
          CpTextField(
            fieldKey: Key('events.settings.venue.$index.mapUrl'),
            label: schedule.venueMapLabel,
            enabled: enabled,
            controller: venue.mapUrl,
            keyboardType: TextInputType.url,
            validator: (value) {
              final text = value?.trim() ?? '';
              return text.isEmpty || isWebLink(text)
                  ? null
                  : schedule.venueMapInvalid;
            },
          ),
          CpTextField(
            fieldKey: Key('events.settings.venue.$index.directions'),
            label: schedule.venueDirectionsLabel,
            enabled: enabled,
            controller: venue.directions,
            maxLines: 4,
            maxLength: 500,
          ),
        ],
      ),
    );
  }
}

/// Names and saves the event's configuration as the person's own template
/// (Req 65). A failure keeps the name and offers another try.
class _SaveTemplateDialog extends ConsumerStatefulWidget {
  const _SaveTemplateDialog({required this.eventId, required this.initialName});

  final String eventId;
  final String initialName;

  @override
  ConsumerState<_SaveTemplateDialog> createState() =>
      _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends ConsumerState<_SaveTemplateDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName.length > 60
        ? widget.initialName.substring(0, 60)
        : widget.initialName,
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strings = context.strings.templates;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = strings.saveAsTemplateNameRequired);
      return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(memberCallsProvider).saveAsTemplate(widget.eventId, name);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(strings.savedAsTemplate)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = isConnectionFailure(e)
            ? context.strings.dashboard.settingsNeedsConnection
            : strings.saveAsTemplateFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.templates;
    return CpDialog(
      title: strings.saveAsTemplate,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: context.cp.space.md,
          children: [
            Text(
              strings.saveAsTemplateHelp,
              style: context.cp.type.bodyMedium.copyWith(
                color: context.cp.colors.textMuted,
              ),
            ),
            CpTextField(
              fieldKey: const Key('events.settings.saveTemplate.name'),
              label: strings.saveAsTemplateName,
              controller: _name,
              enabled: !_busy,
              maxLength: 60,
              error: _error,
            ),
          ],
        ),
      ),
      actions: [
        CpButton.text(
          key: const Key('events.settings.saveTemplate.cancel'),
          label: strings.cancel,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        CpButton(
          key: const Key('events.settings.saveTemplate.save'),
          label: strings.save,
          busy: _busy,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}

/// "Cover photo" (Spec #186 Req 41): choose one from the phone or computer,
/// replace it, or remove it. The screen is open only with `event.manage`.
class _CoverSection extends ConsumerStatefulWidget {
  const _CoverSection({required this.event});

  final EventModel event;

  @override
  ConsumerState<_CoverSection> createState() => _CoverSectionState();
}

class _CoverSectionState extends ConsumerState<_CoverSection> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final message = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) {
      messenger.showSnackBar(
        SnackBar(
          key: const Key('events.settings.cover.message'),
          content: Text(message),
        ),
      );
    }
  }

  Future<void> _choose() => _run(() async {
    final strings = context.strings.cover;
    final outcome = await ref
        .read(eventCoverServiceProvider)
        .choose(widget.event.id);
    return switch (outcome) {
      CoverOutcome.saved => strings.saved,
      CoverOutcome.cancelled => null,
      CoverOutcome.tooLarge => strings.tooLarge,
      CoverOutcome.notAnImage => strings.notAnImage,
      CoverOutcome.failed => strings.failed,
    };
  });

  Future<void> _remove() => _run(() async {
    final strings = context.strings.cover;
    final ok = await ref
        .read(eventCoverServiceProvider)
        .remove(widget.event.id);
    return ok ? strings.removed : strings.removeFailed;
  });

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.cover;
    final hasCover = widget.event.cover != null;
    return CpCard(
      key: const Key('events.settings.cover'),
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          Semantics(
            header: true,
            child: Text(
              strings.heading,
              style: cp.type.titleLarge.copyWith(color: cp.colors.text),
            ),
          ),
          Text(
            strings.help,
            style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
          ),
          EventCoverBanner(event: widget.event),
          if (!hasCover)
            Text(
              strings.none,
              key: const Key('events.settings.cover.none'),
              style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
            ),
          Wrap(
            spacing: cp.space.sm,
            runSpacing: cp.space.sm,
            children: [
              CpButton.secondary(
                key: const Key('events.settings.cover.choose'),
                icon: CpIcons.photoLibrary,
                label: hasCover ? strings.replace : strings.choose,
                busy: _busy,
                onPressed: _choose,
              ),
              if (hasCover)
                CpButton.text(
                  key: const Key('events.settings.cover.remove'),
                  icon: CpIcons.actionDelete,
                  label: strings.remove,
                  onPressed: _busy ? null : _remove,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
