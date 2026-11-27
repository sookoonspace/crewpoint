import 'package:crewpoint_app/app/features/schedule/presentation/attendance_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/layout/cp_list_detail.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:crewpoint_app/app/features/participants/presentation/widgets/answer_input.dart';
import 'package:crewpoint_app/app/features/participants/presentation/group_sheets.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/phone.dart';

/// The route ID that opens the screen on a new participant.
const newParticipantId = 'new';

/// Matches the name limit in `firestore.rules`.
const _maxName = 120;

/// One participant (Req 40, route `people/:participantId`). Anyone may be
/// added with `participants.edit`. A linked adult adds or edits people,
/// children included, in their own groups only. The birth date is private
/// (Z-01): it is shown only to those who may read it.
class ParticipantScreen extends ConsumerStatefulWidget {
  const ParticipantScreen({
    super.key,
    required this.event,
    required this.participantId,
    this.initialGroupId,
  });

  final EventModel event;
  final String participantId;

  /// For a new participant, the group the roster was showing.
  final String? initialGroupId;

  @override
  ConsumerState<ParticipantScreen> createState() => _ParticipantScreenState();
}

class _ParticipantScreenState extends ConsumerState<ParticipantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String? _groupId;
  String? _groupName;
  bool _isChild = false;
  String? _birthDate;

  /// An imported email, kept when the private details are saved (Req 46).
  String? _privateEmail;
  bool? _photoConsent;

  /// An adult's phone number as typed, saved in E.164 (Spec #233 Req 13).
  final _phone = TextEditingController();

  /// Whether the private part (birth date and private answers) changed.
  bool _birthDateChanged = false;
  String? _categoryId;

  /// Worked out from the birth date by the event's age rules, when one fits
  /// (Req 42). It wins over a category picked by hand.
  EventCategory? _derived;
  Map<String, Object?> _answers = {};
  Map<String, Object?> _privateAnswers = {};

  /// Their stay and attendance exceptions (Req 50).
  DateTime? _arrivalAt;
  DateTime? _departureAt;
  List<String> _optOuts = const [];
  List<String> _signUps = const [];
  List<String> _invitedTo = const [];

  /// What was loaded, to tell whether anything changed.
  ParticipantModel? _saved;
  bool _loaded = false;
  bool _privateLoaded = false;
  bool _busy = false;
  String? _error;
  String? _newId;

  bool get _isNew => widget.participantId == newParticipantId;

  String get _id => _isNew ? (_newId ??= newGroupId()) : widget.participantId;

  ({String eventId, String id}) get _key =>
      (eventId: widget.event.id, id: widget.participantId);

  ParticipantModel get _current => ParticipantModel(
    id: _id,
    eventId: widget.event.id,
    name: _name.text.trim(),
    groupId: _groupId,
    isChild: _derived?.isChild ?? _isChild,
    status: _saved?.status ?? 'active',
    uid: _saved?.uid,
    createdBy: _saved?.createdBy ?? ref.read(currentUserIdProvider),
    categoryId: _derived?.id ?? _categoryId,
    fields: _answers,
    filterTags: _saved?.filterTags ?? const [],
    arrivalAt: _arrivalAt,
    departureAt: _departureAt,
    optOuts: _optOuts,
    signUps: _signUps,
    invitedTo: _invitedTo,
  );

  bool get _dirty =>
      _birthDateChanged ||
      (_isNew
          ? _name.text.trim().isNotEmpty ||
                _isChild ||
                _answers.isNotEmpty ||
                _arrivalAt != null ||
                _departureAt != null ||
                _optOuts.isNotEmpty ||
                _signUps.isNotEmpty ||
                _invitedTo.isNotEmpty
          : (_saved != null && _current != _saved));

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    if (_isNew) {
      _loaded = true;
      _privateLoaded = true;
      _groupId = widget.initialGroupId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Fills the form once. Later changes on the server do not overwrite what
  /// someone is typing.
  void _load(ParticipantModel person) {
    if (_loaded) return;
    _loaded = true;
    _saved = person;
    _name.text = person.name;
    _groupId = person.groupId;
    _isChild = person.isChild;
    _categoryId = person.categoryId;
    _answers = {...person.fields};
    _arrivalAt = person.arrivalAt;
    _departureAt = person.departureAt;
    _optOuts = person.optOuts;
    _signUps = person.signUps;
    _invitedTo = person.invitedTo;
  }

  void _answer(CustomField field, Object? value) => setState(() {
    if (field.isPrivate) {
      _privateAnswers = {..._privateAnswers, field.id: value}
        ..removeWhere((_, v) => v == null);
      _birthDateChanged = true;
    } else {
      _answers = {..._answers, field.id: value}
        ..removeWhere((_, v) => v == null);
    }
  });

  Future<void> _pickGroup({required bool anyGroup, List<String>? own}) async {
    final picked = await GroupPickerSheet.show(
      context,
      event: widget.event,
      allowCreate: anyGroup,
      onlyIds: anyGroup ? null : own,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _groupId = picked.id;
      _groupName = picked.name;
    });
  }

  void _setBirthDate(DateTime? picked) => setState(() {
    _birthDate = picked == null
        ? null
        : '${picked.year.toString().padLeft(4, '0')}-'
              '${picked.month.toString().padLeft(2, '0')}-'
              '${picked.day.toString().padLeft(2, '0')}';
    _birthDateChanged = true;
  });

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard/event/${widget.event.id}/people');
    }
  }

  void _refreshRoster() {
    try {
      ref.read(rosterProvider(widget.event.id).notifier).refresh();
    } catch (_) {}
  }

  /// Answers shown with their problems once a save has been tried.
  bool _tried = false;

  /// The questions this viewer answers here, standard and private.
  List<CustomField> _editableFields = const [];

  int get _answerProblems => [
    for (final f in _editableFields)
      if (checkAnswer(
            f,
            f.isPrivate ? _privateAnswers[f.id] : _answers[f.id],
          ) !=
          null)
        f,
  ].length;

  PhoneCountry get _phoneCountry => countryForTimeZone(widget.event.timeZone);

  /// What goes in private details: E.164, or nothing when the field is
  /// empty. The field's check stops a save with a number that is not whole.
  String? get _savedPhone {
    final typed = _phone.text.trim();
    return typed.isEmpty ? null : normalisePhone(typed, _phoneCountry);
  }

  Future<void> _save() async {
    final nameOk = _formKey.currentState!.validate();
    setState(() => _tried = true);
    if (!nameOk || _answerProblems > 0) return;
    if (_arrivalAt != null &&
        _departureAt != null &&
        _departureAt!.isBefore(_arrivalAt!)) {
      return;
    }
    final strings = context.strings.people;
    final messenger = ScaffoldMessenger.of(context);
    final person = _current;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(participantRepositoryProvider)
          .save(
            person,
            privateDetails: _birthDateChanged
                ? ParticipantPrivate(
                    birthDate: _birthDate,
                    email: _privateEmail,
                    phone: _savedPhone,
                    fields: _privateAnswers,
                    photoConsent: _photoConsent,
                  )
                : null,
            definitions:
                ref.read(eventFieldsProvider(widget.event.id)).value ??
                const [],
          );
      if (!mounted) return;
      setState(() {
        _saved = person;
        _birthDateChanged = false;
        _name.text = person.name;
      });
      messenger.showSnackBar(SnackBar(content: Text(strings.saved)));
      _refreshRoster();
      _close();
    } catch (_) {
      if (mounted) setState(() => _error = strings.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final strings = context.strings.people;
    final confirmed = await confirmAction(
      context,
      title: strings.deleteTitle(_saved?.name ?? ''),
      body: strings.deleteBody,
      action: strings.delete,
      confirmKey: const Key('people.edit.deleteConfirm'),
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(participantRepositoryProvider)
          .delete(widget.event.id, widget.participantId);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(strings.deleted)));
      // Nothing is left to keep.
      setState(() {
        _saved = _current;
        _birthDateChanged = false;
      });
      _refreshRoster();
      _close();
    } catch (_) {
      if (mounted) setState(() => _error = strings.deleteFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final words = event.words;
    final strings = context.strings.people;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final manages = event.can(me, 'participants.edit');
    final browses = event.can(me, 'participants.read');
    final mine = ref.watch(myMemberProvider(event.id));
    final own = mine.value?.groupIds ?? const <String>[];
    final linkedAdult = event.can(me, 'group.editOwn') && own.isNotEmpty;
    // Their own record, once linked by verified email (Req 46).
    final ownRecord =
        !_isNew && mine.value?.participantId == widget.participantId;

    Widget scaffold(Widget body, {Widget? bottom}) => PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context) && mounted) {
          setState(() {
            _saved = _current;
            _birthDateChanged = false;
            if (_isNew) {
              _name.clear();
              _isChild = false;
            }
          });
          navigator.pop();
        }
      },
      // Choosing another person beside the roster asks first (Req 23).
      child: CpUnsavedChanges(
        dirty: _dirty && !_busy,
        child: Scaffold(
          appBar: CpTopBar(
            title: _isNew
                ? strings.newTitle(words.one('participant'))
                : switch (_saved?.name) {
                    null => words.one('participant'),
                    '' => context.strings.links.unnamed,
                    final name => name,
                  },
            leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
            leadingKey: const Key('people.edit.back'),
            onLeading: () => Navigator.of(context).maybePop(),
          ),
          body: body,
          bottomNavigationBar: bottom,
        ),
      ),
    );

    if (!manages && !browses && !linkedAdult && !ownRecord) {
      if (mine.isLoading && !mine.hasValue) {
        return scaffold(const Center(child: CircularProgressIndicator()));
      }
      return scaffold(const NoAccessView());
    }

    if (!_isNew) {
      final person = ref.watch(participantProvider(_key));
      if (person.hasError && !person.hasValue) {
        return scaffold(
          LoadFailedView(
            onRetry: () => ref.invalidate(participantProvider(_key)),
          ),
        );
      }
      if (!person.hasValue) {
        return scaffold(
          const Center(
            child: CircularProgressIndicator(key: Key('people.edit.loading')),
          ),
        );
      }
      final value = person.value;
      if (value == null) {
        return scaffold(
          GoneView(message: strings.notFound(words.one('participant'))),
        );
      }
      _load(value);
    }
    if (_isNew && _groupId == null && !manages && own.isNotEmpty) {
      _groupId = own.first;
    }

    // Editing needs participants.edit, or a linked adult for this group.
    final canEdit =
        event.status != EventStatus.archived &&
        (manages || (linkedAdult && own.contains(_saved?.groupId ?? _groupId)));

    // Private details are read only by those allowed to (Z-01), so nobody
    // else even asks for them.
    final readsPrivate =
        event.can(me, 'participants.readPrivate') ||
        (linkedAdult && own.contains(_saved?.groupId)) ||
        ownRecord;
    if (!_isNew && !_privateLoaded && !readsPrivate) _privateLoaded = true;
    if (!_isNew && !_privateLoaded) {
      final private = ref.watch(participantPrivateProvider(_key));
      if (private.hasValue || private.hasError) {
        _privateLoaded = true;
        _birthDate = private.value?.birthDate;
        _privateEmail = private.value?.email;
        _photoConsent = private.value?.photoConsent;
        _phone.text = private.value?.phone ?? '';
        _privateAnswers = {...?private.value?.fields};
      }
    }

    final categories = categoriesOf(event.settings);
    // Ages are counted on the event's first calendar day (Req 42).
    final start = event.displayStart ?? DateTime.now();
    _derived = categoryFor(_birthDate, start, categories);
    final fields = <CustomField>[
      for (final f
          in ref.watch(eventFieldsProvider(event.id)).value ??
              const <CustomField>[])
        if (f.scope == FieldScope.participant) f,
    ];
    // Private details are entered only by those who can read them, or for
    // someone new, so an editor who cannot see them never overwrites them.
    final editsPrivate = canEdit && (readsPrivate || _isNew);
    final showsPrivate = readsPrivate || _isNew;
    final groupId = _groupId;
    final groupName = groupId == null
        ? null
        : (_groupName ??
              ref
                  .watch(groupsByIdProvider((eventId: event.id, ids: groupId)))
                  .value?[groupId]
                  ?.name);

    // Every question is answered here, private ones only by someone who
    // may (Z-01).
    _editableFields = [
      for (final f in fields)
        if (f.isPrivate ? editsPrivate : canEdit) f,
    ];
    final cp = context.cp;
    final groupWord = words.one('group');
    final standardFields = [
      for (final f in fields)
        if (!f.isPrivate) f,
    ];
    final privateFields = [
      for (final f in fields)
        if (f.isPrivate && showsPrivate) f,
    ];
    final problems = _tried ? _answerProblems : 0;
    final fieldStrings = context.strings.fields;

    Widget answer(CustomField f) {
      final editable = !_busy && (f.isPrivate ? editsPrivate : canEdit);
      return IgnorePointer(
        ignoring: !editable,
        child: AnswerInput(
          key: Key('people.question.${f.id}'),
          field: f,
          keyPrefix: 'people',
          value: f.isPrivate ? _privateAnswers[f.id] : _answers[f.id],
          showError: _tried,
          onChanged: (v) => _answer(f, v),
        ),
      );
    }

    final details = CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          CpTextField(
            label: strings.nameLabel,
            fieldKey: const Key('people.edit.name'),
            controller: _name,
            enabled: canEdit && !_busy,
            required: true,
            requiredLabel: context.strings.groupEntry.required,
            textInputAction: TextInputAction.next,
            validator: (v) {
              final name = v?.trim() ?? '';
              if (name.isEmpty) return strings.nameRequired;
              if (name.length > _maxName) return strings.nameTooLong(_maxName);
              return null;
            },
          ),
          CpSwitchRow(
            key: const Key('people.edit.child'),
            title: strings.childLabel,
            help: strings.childHelp,
            value: _derived?.isChild ?? _isChild,
            onChanged: canEdit && !_busy && _derived == null
                ? (on) => setState(() => _isChild = on)
                : null,
          ),
          CpSelectField(
            label: strings.groupLabel(groupWord),
            fieldKey: const Key('people.edit.group'),
            leadingIcon: CpIcons.members,
            value: groupName,
            placeholder: strings.noGroup(groupWord),
            onTap: canEdit && !_busy
                ? () => _pickGroup(anyGroup: manages, own: own)
                : null,
            clearLabel: strings.noGroup(groupWord),
            clearKey: const Key('people.edit.groupClear'),
            onClear: canEdit && manages && !_busy
                ? () => setState(() {
                    _groupId = null;
                    _groupName = null;
                  })
                : null,
          ),
          if (categories.isNotEmpty)
            _derived != null
                ? CpField(
                    key: const Key('people.edit.category'),
                    label: fieldStrings.categoryLabel(words.one('category')),
                    child: Text(
                      fieldStrings.derivedCategory(_derived!.name),
                      style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                    ),
                  )
                : IgnorePointer(
                    ignoring: !canEdit || _busy,
                    child: CpChoiceChips<String>(
                      key: const Key('people.edit.category'),
                      label: words.one('category'),
                      choices: [
                        for (final c in categories)
                          CpChoice(
                            c.id,
                            c.name,
                            key: Key('people.edit.category.${c.id}'),
                          ),
                      ],
                      selected: {
                        if (categories.any((c) => c.id == _categoryId))
                          _categoryId!,
                      },
                      onChanged: (ids) => setState(
                        () => _categoryId = ids.isEmpty ? null : ids.first,
                      ),
                    ),
                  ),
        ],
      ),
    );

    final adult = !(_derived?.isChild ?? _isChild);
    final showsPhone = adult && (editsPrivate || _phone.text.isNotEmpty);
    final privateSection =
        editsPrivate ||
            _birthDate != null ||
            _phone.text.isNotEmpty ||
            privateFields.isNotEmpty
        ? Container(
            key: const Key('people.edit.private'),
            padding: EdgeInsets.all(cp.space.lg),
            decoration: BoxDecoration(
              color: cp.colors.fill,
              borderRadius: cp.radii.md,
              border: Border.all(
                color: cp.colors.border,
                width: cp.sizes.hairline,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.lg,
              children: [
                Row(
                  spacing: cp.space.sm,
                  children: [
                    Icon(
                      CpIcons.lock,
                      size: cp.sizes.iconMd - 2,
                      color: cp.colors.accent,
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          context.strings.groupEntry.privateHeading,
                          style: cp.type.titleSmall.copyWith(
                            color: cp.colors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  strings.birthDateHelp,
                  style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
                ),
                if (editsPrivate || _birthDate != null)
                  CpDateField(
                    key: const Key('people.edit.birthDateField'),
                    fieldKey: const Key('people.edit.birthDate'),
                    clearKey: const Key('people.edit.birthDateClear'),
                    label: strings.birthDateLabel,
                    value: DateTime.tryParse(_birthDate ?? ''),
                    enabled: editsPrivate && !_busy,
                    placeholder: '',
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    clearLabel: strings.clearBirthDate,
                    format: (d) =>
                        MaterialLocalizations.of(context).formatShortDate(d),
                    onChanged: _setBirthDate,
                  ),
                if (showsPhone)
                  CpTextField(
                    label: context.strings.groupEntry.phoneLabel,
                    fieldKey: const Key('people.edit.phone'),
                    controller: _phone,
                    enabled: editsPrivate && !_busy,
                    help: context.strings.groupEntry.phoneHelp,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    onChanged: (_) => setState(() => _birthDateChanged = true),
                    validator: (v) {
                      final typed = v?.trim() ?? '';
                      return typed.isEmpty ||
                              normalisePhone(typed, _phoneCountry) != null
                          ? null
                          : context.strings.groupEntry.phoneInvalid;
                    },
                  ),
                for (final f in privateFields) answer(f),
              ],
            ),
          )
        : null;

    final saveBar = canEdit
        ? Material(
            color: cp.colors.surface,
            child: SafeArea(
              top: false,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: cp.colors.border)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(cp.space.md),
                  child: Row(
                    spacing: cp.space.md,
                    children: [
                      Expanded(
                        child: problems == 0
                            ? const SizedBox.shrink()
                            : CpFieldError(
                                context.strings.groupEntry.missingCount(
                                  problems,
                                ),
                              ),
                      ),
                      Flexible(
                        child: CpButton(
                          key: const Key('people.edit.save'),
                          label: strings.save,
                          busy: _busy,
                          onPressed: _save,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : null;

    return scaffold(
      SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.sm,
          cp.space.lg,
          cp.space.xxl,
        ),
        child: ContentMaxWidth(
          maxWidth: cp.sizes.phoneColumn,
          child: Form(
            key: _formKey,
            child: Column(
              key: const Key('people.edit.body'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.lg,
              children: [
                if (_error != null)
                  Container(
                    key: const Key('people.edit.error'),
                    padding: EdgeInsets.all(cp.space.md),
                    decoration: BoxDecoration(
                      color: cp.colors.overdueSoft,
                      borderRadius: cp.radii.md,
                    ),
                    child: CpFieldError(_error!),
                  ),
                if (!canEdit)
                  Text(
                    strings.readOnly,
                    key: const Key('people.edit.readOnly'),
                    style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                  ),
                if (_saved?.anonymised ?? false)
                  Text(
                    context.strings.links.unnamedHint,
                    key: const Key('people.edit.unnamed'),
                    style: cp.type.bodyMedium.copyWith(
                      color: cp.colors.textMuted,
                    ),
                  ),
                details,
                if (standardFields.isNotEmpty)
                  CpSectionHeader(
                    title: context.strings.groupEntry.questionsHeading,
                  ),
                if (standardFields.isNotEmpty)
                  CpCard(
                    padding: EdgeInsets.all(cp.space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: cp.space.lg,
                      children: [for (final f in standardFields) answer(f)],
                    ),
                  ),
                ?privateSection,
                if (event.isModuleOn('schedule'))
                  AttendanceSection(
                    event: event,
                    sessions:
                        ref.watch(sessionListProvider(event.id)).value ??
                        const [],
                    person: _current.attendee(
                      groupId == null
                          ? const []
                          : ref
                                    .watch(
                                      groupsByIdProvider((
                                        eventId: event.id,
                                        ids: groupId,
                                      )),
                                    )
                                    .value?[groupId]
                                    ?.invitedTo ??
                                const [],
                    ),
                    enabled: canEdit && !_busy,
                    canInvite: manages,
                    onStay: ({arrivalAt, departureAt}) => setState(() {
                      _arrivalAt = arrivalAt;
                      _departureAt = departureAt;
                    }),
                    onExceptions: (e) => setState(() {
                      _optOuts = e.optOuts;
                      _signUps = e.signUps;
                      _invitedTo = e.invitedTo;
                    }),
                  ),
                if (canEdit && !_isNew)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CpButton.text(
                      key: const Key('people.edit.delete'),
                      icon: CpIcons.actionDelete,
                      label: strings.delete,
                      onPressed: _busy ? null : _delete,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottom: saveBar,
    );
  }
}
