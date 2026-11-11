import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart'
    show EventWriteResult;
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart'
    show eventFieldsProvider;
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:crewpoint_app/app/features/schedule/presentation/session_tile.dart';
import 'package:crewpoint_app/app/features/schedule/presentation/venue_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// `schedule/:sessionId` (Req 48): the session's details, or a form for
/// `schedule.edit`. `new` adds a session.
class SessionScreen extends ConsumerWidget {
  const SessionScreen({
    super.key,
    required this.event,
    required this.sessionId,
  });

  final EventModel event;
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.schedule;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final edits = event.canEditSchedule(me);
    final sessions = ref.watch(sessionListProvider(event.id));
    final isNew = sessionId == 'new';

    if (isNew && edits) {
      return _SessionForm(
        event: event,
        session: null,
        suggestions: typeSuggestions(sessions.value ?? const []),
      );
    }
    final list = sessions.value;
    if (list == null) {
      return Scaffold(
        appBar: AppBar(),
        body: sessions.hasError
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.md,
                  children: [
                    Text(
                      strings.loadFailed,
                      key: const Key('schedule.detail.error'),
                    ),
                    FilledButton(
                      key: const Key('schedule.detail.retry'),
                      onPressed: () =>
                          ref.invalidate(sessionListProvider(event.id)),
                      child: Text(strings.retry),
                    ),
                  ],
                ),
              )
            : const Center(
                child: CircularProgressIndicator(
                  key: Key('schedule.detail.loading'),
                ),
              ),
      );
    }
    final session = list.where((s) => s.id == sessionId).firstOrNull;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              strings.missing,
              key: const Key('schedule.detail.missing'),
            ),
          ),
        ),
      );
    }
    if (edits) {
      return _SessionForm(
        event: event,
        session: session,
        suggestions: typeSuggestions(list),
      );
    }
    return _SessionDetail(event: event, session: session);
  }
}

/// Who a session is for, in words: category names and field answers.
String eligibilityLabel(
  BuildContext context,
  EventModel event,
  SessionEligibility e,
  List<CustomField> fields,
) {
  final strings = context.strings.schedule;
  if (e.isEveryone) return strings.forEveryone;
  final categories = {
    for (final c in categoriesOf(event.settings)) c.id: c.name,
  };
  final labels = {for (final f in fields) f.id: f};
  String answer(String tag) {
    final i = tag.indexOf('=');
    if (i < 0) return tag;
    final field = labels[tag.substring(0, i)];
    final value = tag.substring(i + 1);
    if (field == null) return value;
    final shown = field.type == FieldType.yesNo
        ? (value == 'yes'
              ? context.strings.fields.yes
              : context.strings.fields.no)
        : value;
    return '${field.label}: $shown';
  }

  return strings.forOnly(
    [
      for (final id in e.categoryIds) categories[id] ?? id,
      for (final tag in e.filterTags) answer(tag),
    ].join(', '),
  );
}

class _SessionDetail extends ConsumerWidget {
  const _SessionDetail({required this.event, required this.session});

  final EventModel event;
  final SessionModel session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.schedule;
    final theme = Theme.of(context);
    final fields = ref.watch(eventFieldsProvider(event.id)).value ?? const [];
    final venue = venueOf(event, session);
    final note = zoneNoteFor(
      event.timeZone,
      ref.watch(deviceZoneNameProvider).value,
      at: session.startAt,
    );
    final time = sessionTimeLabel(event, session, withDay: true);

    Widget line(IconData icon, String text, String key) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.md,
      children: [
        Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        Expanded(
          child: Text(text, key: Key(key), style: theme.textTheme.bodyLarge),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(event.words.one('session'))),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.lg,
        ),
        children: [
          ContentMaxWidth(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.lg,
              children: [
                Text(
                  session.title,
                  key: const Key('schedule.detail.title'),
                  style: theme.textTheme.headlineSmall,
                ),
                line(
                  AppIcons.schedule,
                  note == null ? time : '$time · $note',
                  'schedule.detail.time',
                ),
                if (session.timeTbc)
                  line(
                    AppIcons.statusInfo,
                    strings.timeTbc,
                    'schedule.detail.tbc',
                  ),
                if (session.type != null)
                  line(AppIcons.event, session.type!, 'schedule.detail.type'),
                if (session.tags.isNotEmpty)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final tag in session.tags) Chip(label: Text(tag)),
                    ],
                  ),
                if (session.capacity != null)
                  line(
                    AppIcons.members,
                    strings.capacity(session.capacity!),
                    'schedule.detail.capacity',
                  ),
                line(
                  AppIcons.member,
                  eligibilityLabel(context, event, session.eligibility, fields),
                  'schedule.detail.eligibility',
                ),
                if (venue != null)
                  VenueCard(venue: venue)
                else if (session.locationTba)
                  line(
                    AppIcons.place,
                    strings.locationTba,
                    'schedule.detail.locationTba',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionForm extends ConsumerStatefulWidget {
  const _SessionForm({
    required this.event,
    required this.session,
    required this.suggestions,
  });

  final EventModel event;
  final SessionModel? session;
  final List<String> suggestions;

  @override
  ConsumerState<_SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends ConsumerState<_SessionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _type;
  late final TextEditingController _capacity;
  final _tag = TextEditingController();
  final _typeFocus = FocusNode();
  DateTime? _day;
  TimeOfDay? _start;
  TimeOfDay? _end;
  late bool _timeTbc;
  String? _venueId;
  late bool _locationTba;
  late List<String> _tags;
  late Set<String> _categoryIds;
  late Set<String> _filterTags;
  late bool _hidden;
  AttendancePolicy? _attendance;
  bool _dirty = false;
  bool _busy = false;
  String? _error;

  EventModel get _event => widget.event;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _title = TextEditingController(text: s?.title ?? '')
      ..addListener(_markDirty);
    _type = TextEditingController(text: s?.type ?? '')..addListener(_markDirty);
    _capacity = TextEditingController(text: s?.capacity?.toString() ?? '')
      ..addListener(_markDirty);
    if (s != null) {
      final start = _event.inZone(s.startAt);
      _day = DateTime(start.year, start.month, start.day);
      _start = TimeOfDay(hour: start.hour, minute: start.minute);
      if (s.endAt != null) {
        final end = _event.inZone(s.endAt!);
        _end = TimeOfDay(hour: end.hour, minute: end.minute);
      }
    }
    _timeTbc = s?.timeTbc ?? false;
    _venueId = _event.venues.any((v) => v.id == s?.venueId) ? s!.venueId : null;
    _locationTba = s?.locationTba ?? false;
    _tags = [...?s?.tags];
    _categoryIds = {...?s?.eligibility.categoryIds};
    _filterTags = {...?s?.eligibility.filterTags};
    _hidden = s?.hidden ?? false;
    _attendance = s?.attendance;
  }

  @override
  void dispose() {
    _title.dispose();
    _type.dispose();
    _capacity.dispose();
    _tag.dispose();
    _typeFocus.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _change(VoidCallback update) => setState(() {
    update();
    _dirty = true;
  });

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  bool get _endsNextDay =>
      _start != null && _end != null && _minutes(_end!) <= _minutes(_start!);

  Future<void> _pickDay() async {
    final first = DateTime(2000);
    final last = DateTime(2100);
    final initial = _day ?? _event.displayStart ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) || initial.isAfter(last)
          ? DateTime.now()
          : initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) _change(() => _day = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (start ? _start : _end) ??
          _start ??
          const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    _change(() => start ? _start = picked : _end = picked);
  }

  void _addTag() {
    final tag = _tag.text.trim();
    if (tag.isEmpty) return;
    _change(() {
      if (!_tags.contains(tag) && _tags.length < 20) _tags.add(tag);
      _tag.clear();
    });
  }

  DateTime _utc(TimeOfDay t, {int plusDays = 0}) {
    final d = _day!.add(Duration(days: plusDays));
    return eventLocalToUtc(
      d.year,
      d.month,
      d.day,
      _event.timeZone,
      hour: t.hour,
      minute: t.minute,
    );
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final strings = context.strings.schedule;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final uid = ref.read(currentUserIdProvider) ?? '';
    final capacity = int.tryParse(_capacity.text.trim());
    final session = SessionModel(
      id: widget.session?.id ?? '',
      title: _title.text.trim(),
      startAt: _utc(_start!),
      endAt: _end == null ? null : _utc(_end!, plusDays: _endsNextDay ? 1 : 0),
      timeTbc: _timeTbc,
      venueId: _venueId,
      locationTba: _venueId == null && _locationTba,
      type: _type.text.trim().isEmpty ? null : _type.text.trim(),
      tags: _tags,
      capacity: capacity,
      eligibility: SessionEligibility(
        categoryIds: _categoryIds.toList(),
        filterTags: _filterTags.toList(),
      ),
      hidden: _hidden,
      attendance: _attendance,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    final (result, _) = await ref
        .read(sessionRepositoryProvider)
        .save(_event.id, session, uid: uid);
    if (!mounted) return;
    if (result == EventWriteResult.failed) {
      setState(() {
        _busy = false;
        _error = strings.saveFailed;
      });
      return;
    }
    setState(() {
      _busy = false;
      _dirty = false;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result == EventWriteResult.saved ? strings.saved : strings.pending,
        ),
      ),
    );
    if (router.canPop()) router.pop();
  }

  Future<void> _delete() async {
    final strings = context.strings.schedule;
    final router = GoRouter.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(strings.deleteTitle(_event.words.one('session'))),
        content: Text(strings.deleteBody),
        actions: [
          TextButton(
            key: const Key('schedule.edit.deleteCancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(strings.cancel),
          ),
          TextButton(
            key: const Key('schedule.edit.deleteConfirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(sessionRepositoryProvider)
        .remove(_event.id, widget.session!.id);
    if (!mounted) return;
    if (result == EventWriteResult.failed) {
      setState(() {
        _busy = false;
        _error = strings.deleteFailed;
      });
      return;
    }
    setState(() {
      _busy = false;
      _dirty = false;
    });
    if (router.canPop()) router.pop();
  }

  Future<void> _confirmLeave() async {
    final strings = context.strings.schedule;
    final navigator = Navigator.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(strings.discardTitle),
        content: Text(strings.discardBody),
        actions: [
          TextButton(
            key: const Key('schedule.edit.keepEditing'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(strings.keepEditing),
          ),
          TextButton(
            key: const Key('schedule.edit.discard'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(strings.discard),
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
    final strings = context.strings.schedule;
    final theme = Theme.of(context);
    final words = _event.words;
    final categories = categoriesOf(_event.settings);
    final fields = [
      for (final f
          in ref.watch(eventFieldsProvider(_event.id)).value ??
              const <CustomField>[])
        if (f.filters && f.scope == FieldScope.participant) f,
    ];
    final time = MaterialLocalizations.of(context);
    const border = OutlineInputBorder();

    Widget picker({
      required String key,
      required String label,
      required String? value,
      required VoidCallback onTap,
      String? error,
      Widget? suffix,
      String? helper,
    }) => FormField<String>(
      validator: (_) => error,
      builder: (state) => InkWell(
        key: Key(key),
        onTap: _busy ? null : onTap,
        child: InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            labelText: label,
            border: border,
            errorText: state.errorText,
            helperText: helper,
            suffixIcon: suffix,
          ),
          child: Text(value ?? ''),
        ),
      ),
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.session == null
                ? strings.newTitle(words.one('session'))
                : strings.editTitle(words.one('session')),
          ),
          actions: [
            if (widget.session != null)
              IconButton(
                key: const Key('schedule.edit.delete'),
                tooltip: strings.delete,
                onPressed: _busy ? null : _delete,
                icon: const Icon(AppIcons.actionDelete),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Breakpoints.screenHorizontalPadding(context),
            vertical: AppSpacing.lg,
          ),
          child: ContentMaxWidth(
            maxWidth: 640,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.lg,
                children: [
                  TextFormField(
                    key: const Key('schedule.edit.title'),
                    controller: _title,
                    enabled: !_busy,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: strings.titleLabel,
                      border: border,
                    ),
                    validator: (v) => (v?.trim().isEmpty ?? true)
                        ? strings.titleRequired
                        : null,
                  ),
                  picker(
                    key: 'schedule.edit.day',
                    label: strings.dayLabel,
                    value: _day == null
                        ? null
                        : DateFormat.yMMMMEEEEd().format(_day!),
                    onTap: _pickDay,
                    error: _day == null ? strings.dayRequired : null,
                    suffix: const Icon(AppIcons.calendar),
                  ),
                  picker(
                    key: 'schedule.edit.start',
                    label: strings.startLabel,
                    value: _start == null
                        ? null
                        : time.formatTimeOfDay(_start!),
                    onTap: () => _pickTime(start: true),
                    error: _start == null ? strings.startRequired : null,
                    suffix: const Icon(AppIcons.schedule),
                  ),
                  picker(
                    key: 'schedule.edit.end',
                    label: strings.endLabel,
                    value: _end == null ? null : time.formatTimeOfDay(_end!),
                    onTap: () => _pickTime(start: false),
                    helper: _endsNextDay ? strings.endNextDay : null,
                    suffix: _end == null
                        ? const Icon(AppIcons.schedule)
                        : IconButton(
                            key: const Key('schedule.edit.end.clear'),
                            tooltip: strings.clearEnd,
                            onPressed: () => _change(() => _end = null),
                            icon: const Icon(AppIcons.actionClear),
                          ),
                  ),
                  SwitchListTile(
                    key: const Key('schedule.edit.timeTbc'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.timeTbcLabel),
                    subtitle: Text(strings.timeTbcHelp),
                    value: _timeTbc,
                    onChanged: _busy
                        ? null
                        : (v) => _change(() => _timeTbc = v),
                  ),
                  DropdownButtonFormField<String?>(
                    key: const Key('schedule.edit.venue'),
                    initialValue: _venueId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings.venueLabel,
                      helperText: _event.venues.isEmpty
                          ? strings.venueHelpNoVenues
                          : null,
                      border: border,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(strings.venueNone),
                      ),
                      for (final v in _event.venues)
                        DropdownMenuItem(value: v.id, child: Text(v.name)),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => _change(() => _venueId = v),
                  ),
                  if (_venueId == null)
                    SwitchListTile(
                      key: const Key('schedule.edit.locationTba'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.locationTbaLabel),
                      value: _locationTba,
                      onChanged: _busy
                          ? null
                          : (v) => _change(() => _locationTba = v),
                    ),
                  RawAutocomplete<String>(
                    textEditingController: _type,
                    focusNode: _typeFocus,
                    optionsBuilder: (value) {
                      final text = value.text.trim().toLowerCase();
                      return widget.suggestions.where(
                        (s) =>
                            s.toLowerCase().contains(text) &&
                            s.toLowerCase() != text,
                      );
                    },
                    fieldViewBuilder: (_, controller, focus, onSubmit) =>
                        TextFormField(
                          key: const Key('schedule.edit.type'),
                          controller: controller,
                          focusNode: focus,
                          enabled: !_busy,
                          maxLength: 40,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: strings.typeLabel,
                            helperText: strings.typeHelp,
                            helperMaxLines: 2,
                            border: border,
                          ),
                          onFieldSubmitted: (_) => onSubmit(),
                        ),
                    optionsViewBuilder: (_, onSelected, options) => Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Material(
                        elevation: 4,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 240,
                            maxWidth: 400,
                          ),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: [
                              for (final option in options)
                                ListTile(
                                  key: Key('schedule.edit.type.$option'),
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.sm,
                    children: [
                      Row(
                        spacing: AppSpacing.sm,
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('schedule.edit.tag'),
                              controller: _tag,
                              enabled: !_busy,
                              maxLength: 30,
                              decoration: InputDecoration(
                                labelText: strings.tagsLabel,
                                border: border,
                                counterText: '',
                              ),
                              onSubmitted: (_) => _addTag(),
                            ),
                          ),
                          IconButton.filledTonal(
                            key: const Key('schedule.edit.tag.add'),
                            tooltip: strings.tagAdd,
                            onPressed: _busy ? null : _addTag,
                            icon: const Icon(AppIcons.actionAdd),
                          ),
                        ],
                      ),
                      if (_tags.isNotEmpty)
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final tag in _tags)
                              InputChip(
                                key: Key('schedule.edit.tag.$tag'),
                                label: Text(tag),
                                deleteButtonTooltipMessage: strings.removeTag(
                                  tag,
                                ),
                                onDeleted: _busy
                                    ? null
                                    : () => _change(() => _tags.remove(tag)),
                              ),
                          ],
                        ),
                    ],
                  ),
                  TextFormField(
                    key: const Key('schedule.edit.capacity'),
                    controller: _capacity,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.capacityLabel,
                      border: border,
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final n = int.tryParse(text);
                      return n == null || n <= 0
                          ? strings.capacityInvalid
                          : null;
                    },
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.sm,
                    children: [
                      Text(
                        strings.eligibilityLabel,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (categories.isEmpty && fields.isEmpty)
                        Text(
                          strings.eligibilityNone,
                          key: const Key('schedule.edit.eligibility.none'),
                          style: theme.textTheme.bodySmall,
                        )
                      else ...[
                        Text(
                          strings.eligibilityHelp,
                          style: theme.textTheme.bodySmall,
                        ),
                        if (categories.isNotEmpty)
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final c in categories)
                                FilterChip(
                                  key: Key('schedule.edit.category.${c.id}'),
                                  label: Text(c.name),
                                  selected: _categoryIds.contains(c.id),
                                  onSelected: _busy
                                      ? null
                                      : (on) => _change(
                                          () => on
                                              ? _categoryIds.add(c.id)
                                              : _categoryIds.remove(c.id),
                                        ),
                                ),
                            ],
                          ),
                        for (final f in fields) ...[
                          Text(f.label, style: theme.textTheme.labelLarge),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final Object v
                                  in f.type == FieldType.yesNo
                                      ? const [true, false]
                                      : f.options)
                                FilterChip(
                                  key: Key(
                                    'schedule.edit.answer.${filterTag(f.id, v)}',
                                  ),
                                  label: Text(
                                    v is bool
                                        ? (v
                                              ? context.strings.fields.yes
                                              : context.strings.fields.no)
                                        : '$v',
                                  ),
                                  selected: _filterTags.contains(
                                    filterTag(f.id, v),
                                  ),
                                  onSelected: _busy
                                      ? null
                                      : (on) => _change(
                                          () => on
                                              ? _filterTags.add(
                                                  filterTag(f.id, v),
                                                )
                                              : _filterTags.remove(
                                                  filterTag(f.id, v),
                                                ),
                                        ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                  DropdownButtonFormField<AttendancePolicy?>(
                    key: const Key('schedule.edit.attendance'),
                    initialValue: _attendance,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.strings.agenda.sessionRuleLabel,
                      helperText: context.strings.agenda.policyHelp(
                        (_attendance ?? _event.attendancePolicy).name,
                      ),
                      helperMaxLines: 3,
                      border: border,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          '${context.strings.agenda.sessionRuleFollow} '
                          '(${context.strings.agenda.policy(_event.attendancePolicy.name)})',
                        ),
                      ),
                      for (final p in AttendancePolicy.values)
                        DropdownMenuItem(
                          value: p,
                          child: Text(context.strings.agenda.policy(p.name)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => _change(() => _attendance = v),
                  ),
                  SwitchListTile(
                    key: const Key('schedule.edit.hidden'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.hiddenLabel),
                    subtitle: Text(strings.hiddenHelp),
                    value: _hidden,
                    onChanged: _busy ? null : (v) => _change(() => _hidden = v),
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      key: const Key('schedule.edit.error'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  FilledButton(
                    key: const Key('schedule.edit.save'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(strings.save),
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
