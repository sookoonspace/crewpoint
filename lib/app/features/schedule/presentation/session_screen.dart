import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
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

/// `schedule/:sessionId` (Req 48; Spec #186): the session's details, or a
/// form for `schedule.edit` in the Person form's pattern. `new` adds a
/// session.
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
    final cp = context.cp;
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

    Widget bare(Widget body) => Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: event.words.one('session'),
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: () => Navigator.of(context).maybePop(),
      ),
      body: body,
    );

    final list = sessions.value;
    if (list == null) {
      return bare(
        sessions.hasError
            ? CpErrorState(
                key: const Key('schedule.detail.error'),
                title: strings.loadFailed,
                retryLabel: strings.retry,
                retryKey: const Key('schedule.detail.retry'),
                onRetry: () => ref.invalidate(sessionListProvider(event.id)),
              )
            : CpLoadingState(
                key: const Key('schedule.detail.loading'),
                semanticLabel: event.words.one('session'),
              ),
      );
    }
    final session = list.where((s) => s.id == sessionId).firstOrNull;
    if (session == null) {
      return bare(
        CpEmptyState(
          key: const Key('schedule.detail.missing'),
          icon: CpIcons.eventBusy,
          title: strings.missing,
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

/// A session for someone who reads the schedule: the title and its tags in
/// a card, then when, what, how many and who it is for, and the venue.
class _SessionDetail extends ConsumerWidget {
  const _SessionDetail({required this.event, required this.session});

  final EventModel event;
  final SessionModel session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.schedule;
    final fields = ref.watch(eventFieldsProvider(event.id)).value ?? const [];
    final venue = venueOf(event, session);
    final note = zoneNoteFor(
      event.timeZone,
      ref.watch(deviceZoneNameProvider).value,
      at: session.startAt,
    );
    final now =
        ref.watch(minuteProvider).value ?? ref.watch(clockProvider).now();

    Widget icon(IconData data) =>
        Icon(data, size: cp.sizes.iconMd, color: cp.colors.textMuted);

    final tags = <Widget>[
      if (sessionIsOn(session, now))
        CpTag(label: context.strings.agenda.now, dot: true),
      if (session.timeTbc)
        CpTag(
          label: strings.timeTbc,
          tone: CpTagTone.quiet,
          icon: CpIcons.statusInfo,
        ),
      for (final tag in session.tags) CpTag(label: tag, tone: CpTagTone.quiet),
    ];

    final facts = <Widget>[
      CpListRow(
        key: const Key('schedule.detail.time'),
        leading: icon(CpIcons.schedule),
        title: sessionTimeLabel(event, session, withDay: true),
        subtitle: note,
      ),
      if (session.timeTbc)
        CpListRow(
          key: const Key('schedule.detail.tbc'),
          leading: icon(CpIcons.statusInfo),
          title: strings.timeTbc,
        ),
      if (session.type != null)
        CpListRow(
          key: const Key('schedule.detail.type'),
          leading: icon(CpIcons.event),
          title: session.type!,
        ),
      if (session.capacity != null)
        CpListRow(
          key: const Key('schedule.detail.capacity'),
          leading: icon(CpIcons.members),
          title: strings.capacity(session.capacity!),
        ),
      CpListRow(
        key: const Key('schedule.detail.eligibility'),
        leading: icon(CpIcons.member),
        title: eligibilityLabel(context, event, session.eligibility, fields),
      ),
      if (venue == null && session.locationTba)
        CpListRow(
          key: const Key('schedule.detail.locationTba'),
          leading: icon(CpIcons.place),
          title: strings.locationTba,
        ),
    ];

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: event.words.one('session'),
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.sm,
          cp.space.lg,
          cp.space.xxl,
        ),
        child: ContentMaxWidth(
          maxWidth: cp.sizes.phoneColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.lg,
            children: [
              CpCard(
                padding: EdgeInsets.all(cp.space.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: cp.space.md,
                  children: [
                    Text(
                      session.title,
                      key: const Key('schedule.detail.title'),
                      style: cp.type.headlineSmall.copyWith(
                        color: cp.colors.text,
                      ),
                    ),
                    if (tags.isNotEmpty)
                      Wrap(
                        spacing: cp.space.xs,
                        runSpacing: cp.space.xs,
                        children: tags,
                      ),
                  ],
                ),
              ),
              CpCard(child: CpRowGroup(children: facts)),
              if (venue != null) VenueCard(venue: venue),
            ],
          ),
        ),
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

  /// Save was pressed, so missing day and start show their errors.
  bool _tried = false;
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

  /// Rows in a sheet, the chosen one ticked; returns the row picked.
  Future<T?> _choose<T>({
    required String title,
    required List<({T value, String label, Key key})> options,
    required bool Function(T) isChosen,
  }) {
    final cp = context.cp;
    return showCpSheet<T>(
      context: context,
      title: title,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final o in options)
              CpListRow(
                key: o.key,
                title: o.label,
                trailing: isChosen(o.value)
                    ? Icon(
                        CpIcons.statusDone,
                        size: cp.sizes.iconMd,
                        color: cp.colors.accent,
                      )
                    : const SizedBox.shrink(),
                onTap: () => Navigator.of(sheet).pop(o.value),
              ),
          ],
        ),
      ),
    );
  }

  /// The sheet's answer for "No venue", which pops nothing otherwise.
  static const _noVenue = '';

  Future<void> _pickVenue() async {
    final strings = context.strings.schedule;
    final picked = await _choose<String>(
      title: strings.venueLabel,
      options: [
        (
          value: _noVenue,
          label: strings.venueNone,
          key: const Key('schedule.edit.venue.none'),
        ),
        for (final v in _event.venues)
          (value: v.id, label: v.name, key: Key('schedule.edit.venue.${v.id}')),
      ],
      isChosen: (id) => id == (_venueId ?? _noVenue),
    );
    if (picked == null || !mounted) return;
    _change(() => _venueId = picked == _noVenue ? null : picked);
  }

  /// The sheet's answer for following the event's rule.
  static const _follow = 'follow';

  Future<void> _pickAttendance() async {
    final agenda = context.strings.agenda;
    final picked = await _choose<String>(
      title: agenda.sessionRuleLabel,
      options: [
        (
          value: _follow,
          label: _followLabel(),
          key: const Key('schedule.edit.attendance.follow'),
        ),
        for (final p in AttendancePolicy.values)
          (
            value: p.name,
            label: agenda.policy(p.name),
            key: Key('schedule.edit.attendance.${p.name}'),
          ),
      ],
      isChosen: (name) => name == (_attendance?.name ?? _follow),
    );
    if (picked == null || !mounted) return;
    _change(
      () => _attendance = picked == _follow
          ? null
          : AttendancePolicy.values.byName(picked),
    );
  }

  String _followLabel() {
    final agenda = context.strings.agenda;
    return '${agenda.sessionRuleFollow} '
        '(${agenda.policy(_event.attendancePolicy.name)})';
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
    if (_busy) return;
    setState(() => _tried = true);
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk || _day == null || _start == null) return;
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
      builder: (dialog) => CpDialog(
        title: strings.deleteTitle(_event.words.one('session')),
        message: strings.deleteBody,
        actions: [
          CpButton.text(
            key: const Key('schedule.edit.deleteCancel'),
            label: strings.cancel,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          CpButton.destructive(
            key: const Key('schedule.edit.deleteConfirm'),
            label: strings.delete,
            onPressed: () => Navigator.of(dialog).pop(true),
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

  /// Leaves, asking first when something changed.
  Future<void> _leave() async {
    final strings = context.strings.schedule;
    final navigator = Navigator.of(context);
    if (_dirty && !_busy) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialog) => CpDialog(
          title: strings.discardTitle,
          message: strings.discardBody,
          actions: [
            CpButton.text(
              key: const Key('schedule.edit.keepEditing'),
              label: strings.keepEditing,
              onPressed: () => Navigator.of(dialog).pop(false),
            ),
            CpButton.destructive(
              key: const Key('schedule.edit.discard'),
              label: strings.discard,
              onPressed: () => Navigator.of(dialog).pop(true),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
      setState(() => _dirty = false);
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.schedule;
    final agenda = context.strings.agenda;
    final required = context.strings.groupEntry.required;
    final words = _event.words;
    final categories = categoriesOf(_event.settings);
    final fields = [
      for (final f
          in ref.watch(eventFieldsProvider(_event.id)).value ??
              const <CustomField>[])
        if (f.filters && f.scope == FieldScope.participant) f,
    ];
    final time = MaterialLocalizations.of(context);
    final venueName = _event.venues
        .where((v) => v.id == _venueId)
        .firstOrNull
        ?.name;
    final typed = _type.text.trim().toLowerCase();
    final suggestions = [
      for (final s in widget.suggestions)
        if (s.toLowerCase().contains(typed) && s.toLowerCase() != typed) s,
    ];
    final muted = cp.type.bodySmall.copyWith(color: cp.colors.textMuted);

    Widget card(List<Widget> children) => CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: children,
      ),
    );

    String answerLabel(Object v) => v is bool
        ? (v ? context.strings.fields.yes : context.strings.fields.no)
        : '$v';

    final body = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          card([
            CpTextField(
              key: const Key('schedule.edit.title'),
              label: strings.titleLabel,
              controller: _title,
              required: true,
              requiredLabel: required,
              enabled: !_busy,
              maxLength: 120,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? strings.titleRequired : null,
            ),
          ]),
          card([
            CpSelectField(
              fieldKey: const Key('schedule.edit.day'),
              label: strings.dayLabel,
              required: true,
              requiredLabel: required,
              leadingIcon: CpIcons.calendar,
              value: _day == null
                  ? null
                  : DateFormat.yMMMMEEEEd().format(_day!),
              onTap: _busy ? null : _pickDay,
              error: _tried && _day == null ? strings.dayRequired : null,
            ),
            CpSelectField(
              fieldKey: const Key('schedule.edit.start'),
              label: strings.startLabel,
              required: true,
              requiredLabel: required,
              leadingIcon: CpIcons.schedule,
              value: _start == null ? null : time.formatTimeOfDay(_start!),
              onTap: _busy ? null : () => _pickTime(start: true),
              error: _tried && _start == null ? strings.startRequired : null,
            ),
            CpSelectField(
              fieldKey: const Key('schedule.edit.end'),
              label: strings.endLabel,
              leadingIcon: CpIcons.schedule,
              value: _end == null ? null : time.formatTimeOfDay(_end!),
              onTap: _busy ? null : () => _pickTime(start: false),
              help: _endsNextDay ? strings.endNextDay : null,
              onClear: () => _change(() => _end = null),
              clearLabel: strings.clearEnd,
              clearKey: const Key('schedule.edit.end.clear'),
            ),
            CpSwitchRow(
              key: const Key('schedule.edit.timeTbc'),
              title: strings.timeTbcLabel,
              help: strings.timeTbcHelp,
              value: _timeTbc,
              onChanged: _busy ? null : (v) => _change(() => _timeTbc = v),
            ),
          ]),
          card([
            CpSelectField(
              fieldKey: const Key('schedule.edit.venue'),
              label: strings.venueLabel,
              leadingIcon: CpIcons.place,
              value: venueName ?? strings.venueNone,
              help: _event.venues.isEmpty ? strings.venueHelpNoVenues : null,
              onTap: _busy ? null : _pickVenue,
            ),
            if (_venueId == null)
              CpSwitchRow(
                key: const Key('schedule.edit.locationTba'),
                title: strings.locationTbaLabel,
                value: _locationTba,
                onChanged: _busy
                    ? null
                    : (v) => _change(() => _locationTba = v),
              ),
          ]),
          card([
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.sm,
              children: [
                CpTextField(
                  key: const Key('schedule.edit.type'),
                  label: strings.typeLabel,
                  help: strings.typeHelp,
                  controller: _type,
                  enabled: !_busy,
                  maxLength: 40,
                  onChanged: (_) => setState(() {}),
                ),
                if (suggestions.isNotEmpty)
                  Wrap(
                    spacing: cp.space.sm,
                    runSpacing: cp.space.sm,
                    children: [
                      for (final option in suggestions)
                        CpFilterChip(
                          key: Key('schedule.edit.type.$option'),
                          label: option,
                          selected: false,
                          onTap: _busy
                              ? null
                              : () => setState(() {
                                  _type.text = option;
                                  _type.selection = TextSelection.collapsed(
                                    offset: option.length,
                                  );
                                }),
                        ),
                    ],
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.sm,
              children: [
                CpTextField(
                  key: const Key('schedule.edit.tag'),
                  label: strings.tagsLabel,
                  controller: _tag,
                  enabled: !_busy,
                  maxLength: 30,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTag(),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: CpButton.secondary(
                    key: const Key('schedule.edit.tag.add'),
                    label: strings.tagAdd,
                    icon: CpIcons.actionAdd,
                    onPressed: _busy ? null : _addTag,
                  ),
                ),
                if (_tags.isNotEmpty)
                  Wrap(
                    spacing: cp.space.sm,
                    runSpacing: cp.space.sm,
                    children: [
                      for (final tag in _tags)
                        CpFilterChip(
                          key: Key('schedule.edit.tag.$tag'),
                          label: tag,
                          selected: true,
                          onClear: _busy
                              ? null
                              : () => _change(() => _tags.remove(tag)),
                          clearKey: Key('schedule.edit.tag.$tag.remove'),
                          clearTooltip: strings.removeTag(tag),
                        ),
                    ],
                  ),
              ],
            ),
            CpTextField(
              key: const Key('schedule.edit.capacity'),
              label: strings.capacityLabel,
              controller: _capacity,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return null;
                final n = int.tryParse(text);
                return n == null || n <= 0 ? strings.capacityInvalid : null;
              },
            ),
          ]),
          CpSectionHeader(title: strings.eligibilityLabel),
          card([
            if (categories.isEmpty && fields.isEmpty)
              Text(
                strings.eligibilityNone,
                key: const Key('schedule.edit.eligibility.none'),
                style: muted,
              )
            else ...[
              Text(strings.eligibilityHelp, style: muted),
              if (categories.isNotEmpty)
                CpChoiceChips<String>(
                  label: words.other('category'),
                  multiple: true,
                  choices: [
                    for (final c in categories)
                      CpChoice(
                        c.id,
                        c.name,
                        key: Key('schedule.edit.category.${c.id}'),
                      ),
                  ],
                  selected: _categoryIds,
                  onChanged: _busy
                      ? null
                      : (ids) => _change(() => _categoryIds = {...ids}),
                ),
              for (final f in fields)
                CpChoiceChips<String>(
                  label: f.label,
                  multiple: true,
                  choices: [
                    for (final Object v
                        in f.type == FieldType.yesNo
                            ? const [true, false]
                            : f.options)
                      CpChoice(
                        filterTag(f.id, v),
                        answerLabel(v),
                        key: Key('schedule.edit.answer.${filterTag(f.id, v)}'),
                      ),
                  ],
                  selected: {
                    for (final t in _filterTags)
                      if (t.startsWith('${f.id}=')) t,
                  },
                  onChanged: _busy
                      ? null
                      : (tags) => _change(() {
                          _filterTags
                            ..removeWhere((t) => t.startsWith('${f.id}='))
                            ..addAll(tags);
                        }),
                ),
            ],
          ]),
          card([
            CpSelectField(
              fieldKey: const Key('schedule.edit.attendance'),
              label: agenda.sessionRuleLabel,
              value: _attendance == null
                  ? _followLabel()
                  : agenda.policy(_attendance!.name),
              help: agenda.policyHelp(
                (_attendance ?? _event.attendancePolicy).name,
              ),
              onTap: _busy ? null : _pickAttendance,
            ),
            CpSwitchRow(
              key: const Key('schedule.edit.hidden'),
              title: strings.hiddenLabel,
              help: strings.hiddenHelp,
              value: _hidden,
              onChanged: _busy ? null : (v) => _change(() => _hidden = v),
            ),
          ]),
          if (_error != null)
            Container(
              padding: EdgeInsets.all(cp.space.md),
              decoration: BoxDecoration(
                color: cp.colors.overdueSoft,
                borderRadius: cp.radii.md,
              ),
              child: CpFieldError(
                _error!,
                key: const Key('schedule.edit.error'),
              ),
            ),
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
                key: const Key('schedule.edit.save'),
                label: strings.save,
                busy: _busy,
                onPressed: _save,
              ),
            ),
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: cp.colors.background,
        appBar: CpTopBar(
          title: widget.session == null
              ? strings.newTitle(words.one('session'))
              : strings.editTitle(words.one('session')),
          leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onLeading: _leave,
          actions: [
            if (widget.session != null)
              CpTopBarAction(
                key: const Key('schedule.edit.delete'),
                icon: CpIcons.actionDelete,
                tooltip: strings.delete,
                onPressed: () {
                  if (!_busy) _delete();
                },
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            cp.space.lg,
            cp.space.sm,
            cp.space.lg,
            cp.space.xxl,
          ),
          child: ContentMaxWidth(maxWidth: cp.sizes.phoneColumn, child: body),
        ),
        bottomNavigationBar: saveBar,
      ),
    );
  }
}
