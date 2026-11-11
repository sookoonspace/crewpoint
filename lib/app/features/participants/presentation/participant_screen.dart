import 'package:crewpoint_app/app/features/schedule/presentation/attendance_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:crewpoint_app/app/features/participants/presentation/field_answer_input.dart';
import 'package:crewpoint_app/app/features/participants/presentation/group_sheets.dart';

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

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial =
        DateTime.tryParse(_birthDate ?? '') ?? DateTime(now.year - 10);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthDate =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      _birthDateChanged = true;
    });
  }

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
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
                    fields: _privateAnswers,
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
    final theme = Theme.of(context);
    final me = ref.watch(currentUserIdProvider) ?? '';
    final manages = event.can(me, 'participants.edit');
    final browses = event.can(me, 'participants.read');
    final mine = ref.watch(myMemberProvider(event.id));
    final own = mine.value?.groupIds ?? const <String>[];
    final linkedAdult = event.can(me, 'group.editOwn') && own.isNotEmpty;
    // Their own record, once linked by verified email (Req 46).
    final ownRecord =
        !_isNew && mine.value?.participantId == widget.participantId;

    Widget scaffold(Widget body) => PopScope(
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isNew
                ? strings.newTitle(words.one('participant'))
                : switch (_saved?.name) {
                    null => words.one('participant'),
                    '' => context.strings.links.unnamed,
                    final name => name,
                  },
          ),
          elevation: 0,
        ),
        body: body,
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

    return scaffold(
      SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.lg,
        ),
        child: ContentMaxWidth(
          maxWidth: 560,
          child: Form(
            key: _formKey,
            child: Column(
              key: const Key('people.edit.body'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.md,
              children: [
                if (!canEdit)
                  Text(
                    strings.readOnly,
                    key: const Key('people.edit.readOnly'),
                    style: theme.textTheme.bodyMedium,
                  ),
                if (_saved?.anonymised ?? false)
                  Text(
                    context.strings.links.unnamedHint,
                    key: const Key('people.edit.unnamed'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                TextFormField(
                  key: const Key('people.edit.name'),
                  controller: _name,
                  enabled: canEdit && !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: strings.nameLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final name = v?.trim() ?? '';
                    if (name.isEmpty) return strings.nameRequired;
                    if (name.length > _maxName) {
                      return strings.nameTooLong(_maxName);
                    }
                    return null;
                  },
                ),
                ListTile(
                  key: const Key('people.edit.group'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.members),
                  title: Text(strings.groupLabel(words.one('group'))),
                  subtitle: Text(
                    groupName ?? strings.noGroup(words.one('group')),
                  ),
                  trailing: canEdit && manages && groupId != null
                      ? IconButton(
                          key: const Key('people.edit.groupClear'),
                          tooltip: strings.noGroup(words.one('group')),
                          icon: const Icon(AppIcons.actionClose),
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _groupId = null;
                                  _groupName = null;
                                }),
                        )
                      : null,
                  onTap: canEdit && !_busy
                      ? () => _pickGroup(anyGroup: manages, own: own)
                      : null,
                ),
                SwitchListTile(
                  key: const Key('people.edit.child'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.childLabel),
                  subtitle: Text(strings.childHelp),
                  value: _derived?.isChild ?? _isChild,
                  onChanged: canEdit && !_busy && _derived == null
                      ? (on) => setState(() => _isChild = on)
                      : null,
                ),
                if (categories.isNotEmpty)
                  _derived != null
                      ? ListTile(
                          key: const Key('people.edit.category'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(AppIcons.members),
                          title: Text(
                            context.strings.fields.categoryLabel(
                              words.one('category'),
                            ),
                          ),
                          subtitle: Text(
                            context.strings.fields.derivedCategory(
                              _derived!.name,
                            ),
                          ),
                        )
                      : DropdownButtonFormField<String?>(
                          key: const Key('people.edit.category'),
                          isExpanded: true,
                          initialValue:
                              categories.any((c) => c.id == _categoryId)
                              ? _categoryId
                              : null,
                          decoration: InputDecoration(
                            labelText: words.one('category'),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              child: Text(context.strings.fields.noCategory),
                            ),
                            for (final c in categories)
                              DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                          ],
                          onChanged: canEdit && !_busy
                              ? (id) => setState(() => _categoryId = id)
                              : null,
                        ),
                if (editsPrivate || _birthDate != null)
                  ListTile(
                    key: const Key('people.edit.birthDate'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.calendar),
                    title: Text(strings.birthDateLabel),
                    subtitle: Text(
                      [?_birthDate, strings.birthDateHelp].join('\n'),
                    ),
                    trailing: editsPrivate && _birthDate != null
                        ? IconButton(
                            key: const Key('people.edit.birthDateClear'),
                            tooltip: strings.clearBirthDate,
                            icon: const Icon(AppIcons.actionClose),
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _birthDate = null;
                                    _birthDateChanged = true;
                                  }),
                          )
                        : null,
                    onTap: editsPrivate && !_busy ? _pickBirthDate : null,
                  ),
                for (final f in fields)
                  if (!f.isPrivate || showsPrivate)
                    FieldAnswerInput(
                      field: f,
                      value: f.isPrivate
                          ? _privateAnswers[f.id]
                          : _answers[f.id],
                      enabled: !_busy && (f.isPrivate ? editsPrivate : canEdit),
                      onChanged: (v) => _answer(f, v),
                    ),
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
                if (_error != null)
                  Text(
                    _error!,
                    key: const Key('people.edit.error'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                if (canEdit)
                  PrimaryButton(
                    key: const Key('people.edit.save'),
                    label: strings.save,
                    isLoading: _busy,
                    onPressed: _save,
                  ),
                if (canEdit && !_isNew)
                  TextButton.icon(
                    key: const Key('people.edit.delete'),
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(AppIcons.actionDelete),
                    label: Text(strings.delete),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
