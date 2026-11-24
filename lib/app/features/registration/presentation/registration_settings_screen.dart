import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

/// Event settings → Registration (Spec #233 Req 67; #239, route
/// `settings/registration`): who can register, capacity, the deadline,
/// review, extra guests, the offer window, the event's link name, the role
/// for people who register, the form's built-in parts, sections and
/// question conditions, and the after-registration note. Questions
/// themselves stay on the Fields screen. Needs `event.manage`; everything
/// but the link name saves through `saveRegistrationSettings`, and the link
/// name through `claimEventSlug`, at once.
class RegistrationSettingsScreen extends ConsumerStatefulWidget {
  const RegistrationSettingsScreen({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<RegistrationSettingsScreen> createState() =>
      _RegistrationSettingsScreenState();
}

const _maxExtraGuests = 20;
const _maxOfferHours = 14 * 24;

class _RegistrationSettingsScreenState
    extends ConsumerState<RegistrationSettingsScreen> {
  /// What the server holds, and what the screen shows, set once the
  /// template's defaults are known.
  RegistrationSettings? _saved;
  late RegistrationSettings _draft;
  int? _savedCapacity;

  final _capacity = TextEditingController();
  final _extraGuests = TextEditingController();
  final _offerHours = TextEditingController();
  final _afterNote = TextEditingController();
  final _laterNote = TextEditingController();
  final _slug = TextEditingController();
  final Map<String, TextEditingController> _sectionNames = {};

  String? _slugSaved;
  bool _slugBusy = false;
  String? _slugError;
  bool _busy = false;
  bool _tried = false;
  String? _error;
  int _newSections = 0;

  EventModel get _event => widget.event;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _capacity,
      _extraGuests,
      _offerHours,
      _afterNote,
      _laterNote,
      _slug,
    ]) {
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _capacity,
      _extraGuests,
      _offerHours,
      _afterNote,
      _laterNote,
      _slug,
      ..._sectionNames.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _start(Map<String, dynamic> templateDefaults) {
    if (_saved != null) return;
    final settings = RegistrationSettings.fromMaps(
      _event.settings['registration'],
      templateDefaults,
    );
    _saved = settings;
    _draft = settings;
    _savedCapacity = _event.capacity;
    _capacity.text = _event.capacity?.toString() ?? '';
    _extraGuests.text = '${settings.extraGuests}';
    _offerHours.text = '${settings.offerHours}';
    _afterNote.text = settings.afterNote?.en ?? '';
    _laterNote.text = settings.laterNote?.en ?? '';
    _slugSaved = settings.slug;
    _slug.text = settings.slug ?? '';
    for (final s in settings.sections) {
      _nameController(s.id, s.name.en);
    }
  }

  TextEditingController _nameController(String id, String text) =>
      _sectionNames.putIfAbsent(
        id,
        () => TextEditingController(text: text)..addListener(_changed),
      );

  int? _number(TextEditingController c) => int.tryParse(c.text.trim());

  LocalText? _text(TextEditingController c, LocalText? before) {
    final en = c.text.trim();
    return en.isEmpty ? null : LocalText(en, gu: before?.gu);
  }

  /// The settings as the screen shows them now.
  RegistrationSettings get _current {
    final later = _text(_laterNote, _draft.laterNote);
    return RegistrationSettings(
      mode: _draft.mode,
      deadline: _draft.deadline,
      review: _draft.review,
      extraGuests: _number(_extraGuests) ?? -1,
      sections: [
        for (final s in _draft.sections)
          s.copyWith(
            name: LocalText(
              _sectionNames[s.id]?.text.trim() ?? s.name.en,
              gu: s.name.gu,
            ),
          ),
      ],
      blocks: _draft.blocks,
      conditions: _draft.conditions,
      afterNote: _text(_afterNote, _draft.afterNote),
      laterNote: later,
      laterNoteFrom: later == null ? null : _draft.laterNoteFrom,
      registrationRoleId: _draft.registrationRoleId,
      offerHours: _number(_offerHours) ?? -1,
      slug: _saved?.slug,
    );
  }

  int? get _capacityValue => _number(_capacity);

  bool get _dirty =>
      _saved != null &&
      (_current != _saved ||
          _capacity.text.trim() != (_savedCapacity?.toString() ?? ''));

  // Problems shown beside their fields once Save was tried.
  String? _capacityProblem(RegistrationSettingsStrings s) {
    final text = _capacity.text.trim();
    if (text.isEmpty) return null;
    final n = int.tryParse(text);
    return n == null || n < 1 ? s.capacityInvalid : null;
  }

  String? _rangeProblem(TextEditingController c, int min, int max, String m) {
    final n = _number(c);
    return n == null || n < min || n > max ? m : null;
  }

  void _edit(RegistrationSettings Function(RegistrationSettings) change) =>
      setState(() => _draft = change(_draft));

  Future<void> _save(RegistrationSettingsStrings s) async {
    setState(() => _tried = true);
    final current = _current;
    final problems = [
      _capacityProblem(s),
      _rangeProblem(_extraGuests, 0, _maxExtraGuests, s.extraGuestsInvalid),
      _rangeProblem(_offerHours, 1, _maxOfferHours, s.offerHoursInvalid),
      if (current.laterNote != null && current.laterNoteFrom == null)
        s.laterNoteNeedsDate,
      if (current.sections.any((x) => x.name.en.isEmpty)) s.sectionNeedsName,
    ].nonNulls;
    if (problems.isNotEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final capacity = _capacityValue;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(memberCallsProvider)
          .saveRegistrationSettings(
            eventId: _event.id,
            settings: current,
            capacity: capacity,
          );
      if (!mounted) return;
      setState(() {
        _saved = current;
        _draft = current;
        _savedCapacity = capacity;
        _tried = false;
      });
      messenger.showSnackBar(SnackBar(content: Text(s.saved)));
    } catch (e, st) {
      if (!mounted) return;
      setState(
        () => _error = userMessageFor(
          e,
          stackTrace: st,
          strings: context.strings.errors,
          fallback: s.saveFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claimSlug(
    RegistrationSettingsStrings s, {
    bool remove = false,
  }) async {
    final typed = _slug.text.trim();
    final slug = remove ? null : normaliseSlug(typed);
    if (!remove && slug == null) {
      setState(() => _slugError = s.slugInvalid);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _slugBusy = true;
      _slugError = null;
    });
    try {
      final kept = await ref
          .read(memberCallsProvider)
          .claimEventSlug(eventId: _event.id, slug: slug);
      if (!mounted) return;
      setState(() {
        _slugSaved = kept;
        _slug.text = kept ?? '';
      });
      messenger.showSnackBar(
        SnackBar(content: Text(remove ? s.slugRemoved : s.slugSaved)),
      );
    } on FirebaseFunctionsException catch (e, st) {
      if (!mounted) return;
      final reason = e.details is Map ? (e.details as Map)['reason'] : null;
      setState(
        () => _slugError = switch (reason) {
          'taken' => s.slugTaken,
          'invalid' => s.slugInvalid,
          _ => userMessageFor(
            e,
            stackTrace: st,
            strings: context.strings.errors,
            fallback: s.slugFailed,
          ),
        },
      );
    } catch (e, st) {
      if (!mounted) return;
      setState(
        () => _slugError = userMessageFor(
          e,
          stackTrace: st,
          strings: context.strings.errors,
          fallback: s.slugFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _slugBusy = false);
    }
  }

  void _addSection(RegistrationSettingsStrings s) {
    _newSections++;
    var id = 'section$_newSections';
    while (_draft.sections.any((x) => x.id == id)) {
      _newSections++;
      id = 'section$_newSections';
    }
    final name = s.newSectionName(_draft.sections.length + 1);
    _nameController(id, name);
    _edit(
      (d) => d.copyWith(
        sections: [
          ...d.sections,
          RegistrationSection(id: id, name: LocalText(name)),
        ],
      ),
    );
  }

  void _moveSection(int index, int by) => _edit((d) {
    final list = [...d.sections];
    final s = list.removeAt(index);
    list.insert(index + by, s);
    return d.copyWith(sections: list);
  });

  void _removeSection(String id) => _edit(
    (d) => d.copyWith(sections: [...d.sections.where((s) => s.id != id)]),
  );

  void _changeSection(String id, List<String> Function(List<String>) change) =>
      _edit(
        (d) => d.copyWith(
          sections: [
            for (final s in d.sections)
              s.id == id ? s.copyWith(fieldIds: change([...s.fieldIds])) : s,
          ],
        ),
      );

  Future<void> _addQuestion(
    RegistrationSection section,
    List<CustomField> free,
    RegistrationSettingsStrings s,
  ) async {
    final picked = await showCpSheet<String>(
      context: context,
      title: s.addQuestionTitle(_event.words.one('customField')),
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final f in free)
              CpListRow(
                key: Key('registration.settings.addQuestion.${f.id}'),
                title: f.label,
                onTap: () => Navigator.of(sheet).pop(f.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    _changeSection(section.id, (ids) => ids..add(picked));
  }

  Future<void> _pickCondition(
    CustomField field,
    List<CustomField> fields,
    List<EventCategory> categories,
    RegistrationSettingsStrings s,
  ) async {
    final fixed = _draft.dependedOn.contains(field.id);
    final current = _draft.conditions[field.id];
    final options = <({FieldCondition? value, String label, Key key})>[
      (
        value: null,
        label: s.shownToEveryone,
        key: const Key('registration.settings.condition.everyone'),
      ),
      if (!fixed) ...[
        for (final c in categories)
          (
            value: CategoryCondition(c.id),
            label: s.onlyCategory(c.name),
            key: Key('registration.settings.condition.category.${c.id}'),
          ),
        for (final target in fields)
          if (_draft.canDependOn(field.id, target.id))
            for (final v in _valuesOf(target, s))
              (
                value: AnswerCondition(target.id, v.value),
                label: s.whenAnswer(target.label, v.label),
                key: Key(
                  'registration.settings.condition.${target.id}.${v.value}',
                ),
              ),
      ],
    ];
    final cp = context.cp;
    final picked = await showCpSheet<({FieldCondition? value})>(
      context: context,
      title: s.conditionTitle(field.label),
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          if (fixed)
            AdminNote(
              s.conditionFixed,
              key: const Key('registration.settings.condition.fixed'),
              icon: CpIcons.statusInfo,
            ),
          CpCard(
            child: CpRowGroup(
              children: [
                for (final o in options)
                  CpListRow(
                    key: o.key,
                    title: o.label,
                    trailing: o.value == current
                        ? Icon(
                            CpIcons.statusDone,
                            size: cp.sizes.iconMd,
                            color: cp.colors.accent,
                            semanticLabel: s.chosen,
                          )
                        : null,
                    onTap: () => Navigator.of(sheet).pop((value: o.value)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    _edit((d) => d.withCondition(field.id, picked.value));
  }

  List<({String value, String label})> _valuesOf(
    CustomField f,
    RegistrationSettingsStrings s,
  ) => switch (f.type) {
    FieldType.yesNo => [
      (value: 'yes', label: s.yes),
      (value: 'no', label: s.no),
    ],
    FieldType.singleChoice ||
    FieldType.multiChoice => [for (final o in f.options) (value: o, label: o)],
    _ => const [],
  };

  String _conditionSummary(
    FieldCondition? c,
    List<CustomField> fields,
    List<EventCategory> categories,
    RegistrationSettingsStrings s,
  ) => switch (c) {
    null => s.shownToEveryone,
    CategoryCondition(:final categoryId) => s.onlyCategory(
      categories.where((x) => x.id == categoryId).firstOrNull?.name ??
          categoryId,
    ),
    AnswerCondition(:final fieldId, :final value) => s.whenAnswer(
      fields.where((f) => f.id == fieldId).firstOrNull?.label ?? fieldId,
      value == 'yes'
          ? s.yes
          : value == 'no'
          ? s.no
          : value,
    ),
  };

  Future<void> _pickRole(
    List<RoleDefinition> roles,
    RegistrationSettingsStrings s,
  ) async {
    final cp = context.cp;
    final picked = await showCpSheet<String>(
      context: context,
      title: s.roleLabel,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final r in roles)
              if (canBeRegistrationRole(r.id, r.permissions))
                CpListRow(
                  key: Key('registration.settings.role.${r.id}'),
                  title: r.name,
                  trailing: r.id == _draft.registrationRoleId
                      ? Icon(
                          CpIcons.statusDone,
                          size: cp.sizes.iconMd,
                          color: cp.colors.accent,
                          semanticLabel: s.chosen,
                        )
                      : null,
                  onTap: () => Navigator.of(sheet).pop(r.id),
                ),
          ],
        ),
      ),
    );
    if (picked != null) _edit((d) => d.copyWith(registrationRoleId: picked));
  }

  Future<void> _pickDeadlineTime() async {
    final deadline = _draft.deadline;
    final local = deadline == null ? null : _event.inZone(deadline);
    final picked = await showTimePicker(
      context: context,
      initialTime: local == null
          ? const TimeOfDay(hour: 23, minute: 59)
          : TimeOfDay(hour: local.hour, minute: local.minute),
    );
    if (picked == null || local == null) return;
    _setDeadline(local, picked);
  }

  void _setDeadline(DateTime day, TimeOfDay time) => _edit(
    (d) => d.copyWith(
      deadline: eventLocalToUtc(
        day.year,
        day.month,
        day.day,
        _event.timeZone,
        hour: time.hour,
        minute: time.minute,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.strings.registrationSettings;
    final words = _event.words;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final title = words.one('registration');

    Widget scaffold(Widget body, {Widget? bottom}) => PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (await confirmDiscard(context) && mounted) {
          setState(() {
            _saved = null;
          });
          if (router.canPop()) {
            router.pop();
          } else {
            router.go('/dashboard/event/${_event.id}/settings');
          }
        }
      },
      child: AdminScaffold(title: title, body: body, bottom: bottom),
    );

    if (!_event.can(me, 'event.manage')) {
      return scaffold(const NoAccessView());
    }

    final fieldsAsync = ref.watch(eventFieldsProvider(_event.id));
    final rolesAsync = ref.watch(eventRolesProvider(_event.id));
    final catalogue = ref.watch(templateCatalogueProvider);
    final failed = [
      fieldsAsync,
      rolesAsync,
    ].any((a) => a.hasError && !a.hasValue);
    if (failed) {
      return scaffold(
        LoadFailedView(
          onRetry: () {
            ref.invalidate(eventFieldsProvider(_event.id));
            ref.invalidate(eventRolesProvider(_event.id));
          },
        ),
      );
    }
    if (!fieldsAsync.hasValue ||
        !rolesAsync.hasValue ||
        (catalogue.isLoading && !catalogue.hasValue)) {
      return scaffold(
        CpLoadingState.rows(
          key: const Key('registration.settings.loading'),
          semanticLabel: title,
        ),
      );
    }
    _start(
      catalogue.value
              ?.where((t) => t.id == _event.templateId)
              .firstOrNull
              ?.registration ??
          const {},
    );
    final fields = [...fieldsAsync.value!]
      ..sort((a, b) => a.order.compareTo(b.order));
    final roles = rolesAsync.value!;
    final categories = categoriesOf(_event.settings);
    final cp = context.cp;
    final enabled = !_busy;
    final placed = {for (final x in _draft.sections) ...x.fieldIds};
    final free = [
      for (final f in fields)
        if (!placed.contains(f.id)) f,
    ];
    final fieldById = {for (final f in fields) f.id: f};
    final group = words.one('group').toLowerCase();
    final groups = words.other('group').toLowerCase();
    final fieldsWord = words.other('customField').toLowerCase();
    final dateFormat = DateFormat.yMMMEd();
    final local = _draft.deadline == null
        ? null
        : _event.inZone(_draft.deadline!);

    Widget card(List<Widget> children) => CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: children,
      ),
    );

    Widget switches(List<Widget> rows) => CpCard(
      padding: EdgeInsets.symmetric(
        horizontal: cp.space.lg,
        vertical: cp.space.xs,
      ),
      child: Column(children: rows),
    );

    CpSwitchRow block(RegistrationBlock b, String title, String help) =>
        CpSwitchRow(
          key: Key('registration.settings.block.${b.name}'),
          title: title,
          help: help,
          value: _draft.has(b),
          onChanged: enabled
              ? (on) => _edit(
                  (d) => d.copyWith(
                    blocks: on ? {...d.blocks, b} : ({...d.blocks}..remove(b)),
                  ),
                )
              : null,
        );

    void pickMode(RegistrationMode? m) {
      if (m != null && enabled) _edit((d) => d.copyWith(mode: m));
    }

    final roleName =
        roles
            .where((r) => r.id == _draft.registrationRoleId)
            .firstOrNull
            ?.name ??
        _draft.registrationRoleId;
    final link = _slugSaved == null
        ? null
        : '${AppFlavor.current.legalBaseUrl}/e/$_slugSaved';

    return scaffold(
      bottom: AdminSaveBar(
        child: CpButton(
          key: const Key('registration.settings.save'),
          label: s.save,
          busy: _busy,
          onPressed: _dirty && !_busy ? () => _save(s) : null,
        ),
      ),
      AdminList(
        listKey: const Key('registration.settings.body'),
        children: [
          AdminNote(s.intro(fieldsWord)),
          CpSectionHeader(title: s.modeHeading),
          RadioGroup<RegistrationMode>(
            key: const Key('registration.settings.mode'),
            groupValue: _draft.mode,
            onChanged: pickMode,
            child: CpCard(
              child: CpRowGroup(
                children: [
                  _ModeOption(
                    key: const Key('registration.settings.mode.open'),
                    mode: RegistrationMode.open,
                    title: s.modeOpen,
                    help: s.modeOpenHelp,
                    enabled: enabled,
                    onTap: () => pickMode(RegistrationMode.open),
                  ),
                  _ModeOption(
                    key: const Key('registration.settings.mode.invited'),
                    mode: RegistrationMode.invited,
                    title: s.modeInvited,
                    help: s.modeInvitedHelp(group),
                    enabled: enabled,
                    onTap: () => pickMode(RegistrationMode.invited),
                  ),
                ],
              ),
            ),
          ),
          CpSectionHeader(title: s.placesHeading),
          card([
            CpTextField(
              fieldKey: const Key('registration.settings.capacity'),
              label: s.capacity,
              help: s.capacityHelp,
              controller: _capacity,
              enabled: enabled,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              error: _tried ? _capacityProblem(s) : null,
            ),
            CpDateField(
              fieldKey: const Key('registration.settings.deadline'),
              clearKey: const Key('registration.settings.deadline.clear'),
              label: s.deadline,
              help: s.deadlineHelp(_event.timeZone),
              placeholder: s.noDeadline,
              clearLabel: s.clear,
              enabled: enabled,
              value: local,
              format: dateFormat.format,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              onChanged: (day) {
                if (day == null) {
                  _edit((d) => d.copyWith(clearDeadline: true));
                } else {
                  _setDeadline(
                    day,
                    local == null
                        ? const TimeOfDay(hour: 23, minute: 59)
                        : TimeOfDay(hour: local.hour, minute: local.minute),
                  );
                }
              },
            ),
            if (local != null)
              CpSelectField(
                fieldKey: const Key('registration.settings.deadlineTime'),
                label: s.deadlineTime,
                value: MaterialLocalizations.of(context).formatTimeOfDay(
                  TimeOfDay(hour: local.hour, minute: local.minute),
                ),
                onTap: enabled ? _pickDeadlineTime : () {},
              ),
            CpTextField(
              fieldKey: const Key('registration.settings.extraGuests'),
              label: s.extraGuests(group),
              help: s.extraGuestsHelp,
              controller: _extraGuests,
              enabled: enabled,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              error: _tried
                  ? _rangeProblem(
                      _extraGuests,
                      0,
                      _maxExtraGuests,
                      s.extraGuestsInvalid,
                    )
                  : null,
            ),
            CpTextField(
              fieldKey: const Key('registration.settings.offerHours'),
              label: s.offerHours,
              help: s.offerHoursHelp,
              controller: _offerHours,
              enabled: enabled,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              error: _tried
                  ? _rangeProblem(
                      _offerHours,
                      1,
                      _maxOfferHours,
                      s.offerHoursInvalid,
                    )
                  : null,
            ),
          ]),
          switches([
            CpSwitchRow(
              key: const Key('registration.settings.review'),
              title: s.review,
              help: s.reviewHelp,
              value: _draft.review,
              onChanged: enabled
                  ? (on) => _edit((d) => d.copyWith(review: on))
                  : null,
            ),
          ]),
          CpSectionHeader(title: s.linkHeading),
          card([
            CpTextField(
              fieldKey: const Key('registration.settings.slug'),
              label: s.slug,
              help: s.slugHelp,
              controller: _slug,
              enabled: !_slugBusy,
              keyboardType: TextInputType.url,
              error: _slugError,
            ),
            KeyedSubtree(
              key: const Key('registration.settings.slug.link'),
              child: Text(
                link == null ? s.noSlug : s.slugLink(link),
                style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
              ),
            ),
            Wrap(
              spacing: cp.space.sm,
              runSpacing: cp.space.sm,
              children: [
                CpButton.secondary(
                  key: const Key('registration.settings.slug.save'),
                  label: s.slugSave,
                  busy: _slugBusy,
                  onPressed:
                      !_slugBusy &&
                          _slug.text.trim().toLowerCase() != (_slugSaved ?? '')
                      ? () => _claimSlug(s)
                      : null,
                ),
                if (_slugSaved != null)
                  CpButton.text(
                    key: const Key('registration.settings.slug.remove'),
                    label: s.slugRemove,
                    onPressed: _slugBusy
                        ? null
                        : () => _claimSlug(s, remove: true),
                  ),
              ],
            ),
          ]),
          CpSectionHeader(title: s.roleHeading),
          card([
            CpSelectField(
              fieldKey: const Key('registration.settings.role'),
              label: s.roleLabel,
              help: s.roleHelp,
              value: roleName,
              onTap: enabled ? () => _pickRole(roles, s) : () {},
            ),
          ]),
          CpSectionHeader(title: s.blocksHeading),
          switches([
            block(RegistrationBlock.people, s.blockPeople, s.blockPeopleHelp),
            if (_draft.has(RegistrationBlock.people))
              block(
                RegistrationBlock.ageOnly,
                s.blockAgeOnly,
                s.blockAgeOnlyHelp,
              ),
            block(RegistrationBlock.stay, s.blockStay, s.blockStayHelp),
            block(
              RegistrationBlock.sessionChoices,
              s.blockSessions(words.other('session')),
              s.blockSessionsHelp(words.other('session').toLowerCase()),
            ),
            block(
              RegistrationBlock.waivers,
              s.blockWaivers,
              s.blockWaiversHelp,
            ),
            block(
              RegistrationBlock.contact,
              s.blockContact,
              s.blockContactHelp,
            ),
          ]),
          CpSectionHeader(
            title: s.sectionsHeading,
            actionLabel: s.addSection,
            actionKey: const Key('registration.settings.addSection'),
            onAction: enabled ? () => _addSection(s) : null,
          ),
          AdminNote(s.sectionsHelp(fieldsWord)),
          if (fields.isEmpty)
            KeyedSubtree(
              key: const Key('registration.settings.noFields'),
              child: AdminNote(
                s.noFields(fieldsWord),
                icon: CpIcons.statusInfo,
              ),
            ),
          if (fields.isNotEmpty || _draft.sections.isNotEmpty)
            CpButton.text(
              key: const Key('registration.settings.editFields'),
              label: s.editFields(words.other('customField')),
              icon: CpIcons.actionEdit,
              onPressed: () =>
                  context.push('/dashboard/event/${_event.id}/fields'),
            ),
          for (final (i, section) in _draft.sections.indexed)
            _SectionCard(
              key: Key('registration.settings.section.${section.id}'),
              section: section,
              nameController: _nameController(section.id, section.name.en),
              nameError:
                  _tried &&
                      (_sectionNames[section.id]?.text.trim().isEmpty ?? false)
                  ? s.sectionNeedsName
                  : null,
              enabled: enabled,
              isFirst: i == 0,
              isLast: i == _draft.sections.length - 1,
              questions: [
                for (final id in section.fieldIds)
                  if (fieldById[id] case final f?)
                    (
                      field: f,
                      shownTo: _conditionSummary(
                        _draft.conditions[f.id],
                        fields,
                        categories,
                        s,
                      ),
                    ),
              ],
              canAdd: free.isNotEmpty,
              strings: s,
              fieldWord: words.one('customField').toLowerCase(),
              onMove: (by) => _moveSection(i, by),
              onRemove: () => _removeSection(section.id),
              onAdd: () => _addQuestion(section, free, s),
              onQuestion: (f) => _pickCondition(f, fields, categories, s),
              onMoveQuestion: (fieldId, by) =>
                  _changeSection(section.id, (ids) {
                    final at = ids.indexOf(fieldId);
                    ids.removeAt(at);
                    ids.insert(at + by, fieldId);
                    return ids;
                  }),
              onRemoveQuestion: (fieldId) =>
                  _changeSection(section.id, (ids) => ids..remove(fieldId)),
            ),
          if (_draft.sections.isNotEmpty && free.isNotEmpty)
            KeyedSubtree(
              key: const Key('registration.settings.unplaced'),
              child: AdminNote(
                s.unplaced(free.map((f) => f.label).join(', ')),
                icon: CpIcons.statusInfo,
              ),
            ),
          CpSectionHeader(title: s.noteHeading),
          AdminNote(s.noteHelp(groups)),
          card([
            CpTextField(
              fieldKey: const Key('registration.settings.afterNote'),
              label: s.note,
              controller: _afterNote,
              enabled: enabled,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
            ),
            CpDateField(
              fieldKey: const Key('registration.settings.laterNoteFrom'),
              clearKey: const Key('registration.settings.laterNoteFrom.clear'),
              label: s.laterNoteFrom,
              help: s.laterNoteFromHelp(groups),
              placeholder: s.notReplaced,
              clearLabel: s.clear,
              enabled: enabled,
              value: _draft.laterNoteFrom == null
                  ? null
                  : _event.inZone(_draft.laterNoteFrom!),
              format: dateFormat.format,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              error:
                  _tried &&
                      _laterNote.text.trim().isNotEmpty &&
                      _draft.laterNoteFrom == null
                  ? s.laterNoteNeedsDate
                  : null,
              onChanged: (day) => _edit(
                (d) => day == null
                    ? d.copyWith(clearLaterNoteFrom: true)
                    : d.copyWith(laterNoteFrom: _event.startOfDay(day)),
              ),
            ),
            CpTextField(
              fieldKey: const Key('registration.settings.laterNote'),
              label: s.laterNote,
              controller: _laterNote,
              enabled: enabled,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
            ),
          ]),
          if (_error != null)
            KeyedSubtree(
              key: const Key('registration.settings.error'),
              child: CpFieldError(_error!),
            ),
        ],
      ),
    );
  }
}

/// One choice of who can register: a radio, its name and what it means.
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    super.key,
    required this.mode,
    required this.title,
    required this.help,
    required this.enabled,
    required this.onTap,
  });

  final RegistrationMode mode;
  final String title;
  final String help;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return MergeSemantics(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: cp.sizes.rowMinHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: cp.space.sm,
                vertical: cp.space.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<RegistrationMode>(
                    value: mode,
                    enabled: enabled,
                    activeColor: cp.colors.accent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: cp.space.md,
                        right: cp.space.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: cp.space.xs / 2,
                        children: [
                          Text(
                            title,
                            style: cp.type.titleSmall.copyWith(
                              color: cp.colors.text,
                            ),
                          ),
                          Text(
                            help,
                            style: cp.type.bodySmall.copyWith(
                              color: cp.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
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

enum _Move { up, down, remove }

/// One section of the form: its name, its questions in order with who
/// each is shown to, and menus to move and remove them.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.section,
    required this.nameController,
    required this.nameError,
    required this.enabled,
    required this.isFirst,
    required this.isLast,
    required this.questions,
    required this.canAdd,
    required this.strings,
    required this.fieldWord,
    required this.onMove,
    required this.onRemove,
    required this.onAdd,
    required this.onQuestion,
    required this.onMoveQuestion,
    required this.onRemoveQuestion,
  });

  final RegistrationSection section;
  final TextEditingController nameController;
  final String? nameError;
  final bool enabled;
  final bool isFirst;
  final bool isLast;
  final List<({CustomField field, String shownTo})> questions;
  final bool canAdd;
  final RegistrationSettingsStrings strings;
  final String fieldWord;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;
  final VoidCallback onAdd;
  final ValueChanged<CustomField> onQuestion;
  final void Function(String fieldId, int by) onMoveQuestion;
  final ValueChanged<String> onRemoveQuestion;

  Widget _menu({
    required BuildContext context,
    required String keyPrefix,
    required String tooltip,
    required bool first,
    required bool last,
    required String removeLabel,
    required void Function(_Move) onSelected,
  }) {
    final cp = context.cp;
    return PopupMenuButton<_Move>(
      key: Key('$keyPrefix.menu'),
      enabled: enabled,
      tooltip: tooltip,
      icon: Icon(
        CpIcons.actionMore,
        size: cp.sizes.iconMd,
        color: cp.colors.textMuted,
      ),
      onSelected: onSelected,
      itemBuilder: (_) => [
        if (!first)
          PopupMenuItem(
            key: Key('$keyPrefix.up'),
            value: _Move.up,
            child: Text(strings.moveUp),
          ),
        if (!last)
          PopupMenuItem(
            key: Key('$keyPrefix.down'),
            value: _Move.down,
            child: Text(strings.moveDown),
          ),
        PopupMenuItem(
          key: Key('$keyPrefix.remove'),
          value: _Move.remove,
          child: Text(removeLabel),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final prefix = 'registration.settings.section.${section.id}';
    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CpTextField(
                  fieldKey: Key('$prefix.name'),
                  label: strings.sectionName,
                  controller: nameController,
                  enabled: enabled,
                  error: nameError,
                ),
              ),
              _menu(
                context: context,
                keyPrefix: prefix,
                tooltip: strings.sectionActions,
                first: isFirst,
                last: isLast,
                removeLabel: strings.removeSection,
                onSelected: (m) => switch (m) {
                  _Move.up => onMove(-1),
                  _Move.down => onMove(1),
                  _Move.remove => onRemove(),
                },
              ),
            ],
          ),
          if (questions.isEmpty)
            Text(
              strings.sectionEmpty(fieldWord),
              style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
            )
          else
            CpRowGroup(
              children: [
                for (final (i, q) in questions.indexed)
                  CpListRow(
                    key: Key('$prefix.question.${q.field.id}'),
                    leading: Icon(
                      CpIcons.shownTo,
                      size: cp.sizes.iconMd,
                      color: cp.colors.accent,
                    ),
                    title: q.field.label,
                    subtitle: q.shownTo,
                    onTap: enabled ? () => onQuestion(q.field) : null,
                    trailing: _menu(
                      context: context,
                      keyPrefix: '$prefix.question.${q.field.id}',
                      tooltip: strings.questionActions(q.field.label),
                      first: i == 0,
                      last: i == questions.length - 1,
                      removeLabel: strings.removeQuestion,
                      onSelected: (m) => switch (m) {
                        _Move.up => onMoveQuestion(q.field.id, -1),
                        _Move.down => onMoveQuestion(q.field.id, 1),
                        _Move.remove => onRemoveQuestion(q.field.id),
                      },
                    ),
                  ),
              ],
            ),
          if (canAdd)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CpButton.text(
                key: Key('$prefix.addQuestion'),
                label: strings.addQuestion(fieldWord),
                icon: CpIcons.actionAdd,
                onPressed: enabled ? onAdd : null,
              ),
            ),
        ],
      ),
    );
  }
}
