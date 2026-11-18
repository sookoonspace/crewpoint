import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/application/group_entry_controller.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/group_draft.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:crewpoint_app/app/features/participants/presentation/widgets/answer_input.dart';
import 'package:crewpoint_app/app/features/participants/presentation/widgets/person_card.dart';

/// What the group screen saved, for People to show it (Req 35).
class GroupEntryResult {
  const GroupEntryResult({
    required this.group,
    required this.count,
    required this.isNewGroup,
  });

  final GroupModel group;
  final int count;
  final bool isNewGroup;
}

/// Adds a whole group, or people to an existing group, with everyone's
/// answers, in one save that is safe to retry (Spec #186 Req 25–36). Route
/// `people/group-entry`, with `?group=` to add to an existing group.
class GroupEntryScreen extends ConsumerStatefulWidget {
  const GroupEntryScreen({super.key, required this.event, this.groupId});

  final EventModel event;

  /// The group to add to; null for a new group.
  final String? groupId;

  @override
  ConsumerState<GroupEntryScreen> createState() => _GroupEntryScreenState();
}

class _GroupEntryScreenState extends ConsumerState<GroupEntryScreen> {
  late final GroupEntryArgs _args = GroupEntryArgs(
    eventId: widget.event.id,
    groupId: widget.groupId,
  );
  late final TextEditingController _groupName = TextEditingController();

  /// The existing group, once read; null for a new group.
  GroupModel? _group;
  bool _loadingGroup = false;
  bool _loadFailed = false;

  /// The message under the save button: offline, or what did not save.
  String? _message;

  /// Set once saved, so leaving does not ask.
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null) _loadGroup();
  }

  @override
  void dispose() {
    _groupName.dispose();
    super.dispose();
  }

  GroupEntryController get _controller =>
      ref.read(groupEntryProvider(_args).notifier);

  bool get _readsPrivate {
    final event = widget.event;
    final me = ref.read(currentUserIdProvider) ?? '';
    if (event.can(me, 'participants.readPrivate')) return true;
    final own =
        ref.read(myMemberProvider(event.id)).value?.groupIds ?? const [];
    return widget.groupId != null &&
        event.can(me, 'group.editOwn') &&
        own.contains(widget.groupId);
  }

  Future<void> _loadGroup() async {
    setState(() {
      _loadingGroup = true;
      _loadFailed = false;
    });
    final repo = ref.read(participantRepositoryProvider);
    try {
      final groups = await repo.groupsByIds(widget.event.id, [widget.groupId!]);
      final group = groups[widget.groupId];
      final private = _readsPrivate
          ? await repo.readGroupPrivate(widget.event.id, widget.groupId!)
          : null;
      if (!mounted) return;
      if (group != null) {
        _controller.loadGroupAnswers(group.fields, private, name: group.name);
      }
      setState(() {
        _group = group;
        _loadingGroup = false;
        _loadFailed = group == null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingGroup = false;
          _loadFailed = true;
        });
      }
    }
  }

  void _edit(GroupDraft Function(GroupDraft d) change) {
    _controller.edit(change);
    if (_message != null) setState(() => _message = null);
  }

  GroupDraft _withPerson(GroupDraft d, PersonDraft person) => GroupDraft(
    groupId: d.groupId,
    isNewGroup: d.isNewGroup,
    groupName: d.groupName,
    groupAnswers: d.groupAnswers,
    groupPrivateAnswers: d.groupPrivateAnswers,
    people: [for (final p in d.people) p.id == person.id ? person : p],
  );

  GroupDraft _withGroup(
    GroupDraft d, {
    String? name,
    Map<String, Object?>? answers,
    Map<String, Object?>? privateAnswers,
  }) => GroupDraft(
    groupId: d.groupId,
    isNewGroup: d.isNewGroup,
    groupName: name ?? d.groupName,
    groupAnswers: answers ?? d.groupAnswers,
    groupPrivateAnswers: privateAnswers ?? d.groupPrivateAnswers,
    people: d.people,
  );

  void _groupAnswer(CustomField field, Object? value) => _edit((d) {
    final target = {
      ...(field.isPrivate ? d.groupPrivateAnswers : d.groupAnswers),
      field.id: value,
    }..removeWhere((_, v) => v == null);
    return field.isPrivate
        ? _withGroup(d, privateAnswers: target)
        : _withGroup(d, answers: target);
  });

  Future<void> _save() async {
    final event = widget.event;
    final strings = context.strings.groupEntry;
    final word = event.words.one('group');
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    final fields = ref.read(eventFieldsProvider(event.id)).value ?? const [];
    final outcome = await _controller.save(
      fields: fields,
      readsPrivate: _readsPrivate,
      createdBy: ref.read(currentUserIdProvider),
      categories: categoriesOf(event.settings),
      eventStart: event.displayStart ?? DateTime.now(),
    );
    if (!mounted) return;
    final state = ref.read(groupEntryProvider(_args));
    switch (outcome) {
      case GroupSaveOutcome.saved:
        final draft = state.draft;
        final count = draft.toSave.length;
        final name = draft.isNewGroup
            ? draft.groupName.trim()
            : (_group?.name ?? draft.groupName);
        try {
          ref.read(rosterProvider(event.id).notifier).refresh();
        } catch (_) {}
        setState(() => _finished = true);
        messenger.showSnackBar(
          SnackBar(
            key: const Key('people.groupEntry.saved'),
            content: Text(
              draft.isNewGroup
                  ? strings.newGroupSaved(name, count)
                  : strings.addedToGroup(name, count),
            ),
          ),
        );
        context.pop(
          GroupEntryResult(
            group: GroupModel(
              id: draft.groupId,
              name: name,
              adultUids: _group?.adultUids ?? const [],
              fields: draft.groupAnswers,
            ),
            count: count,
            isNewGroup: draft.isNewGroup,
          ),
        );
      case GroupSaveOutcome.offline:
        setState(() => _message = strings.offline(word));
      case GroupSaveOutcome.failed:
        setState(
          () => _message = switch (state.failedStep) {
            GroupSaveStep.group => strings.groupFailed(word),
            GroupSaveStep.answers => strings.answersFailed(word),
            _ => strings.peopleFailed(word),
          },
        );
      case GroupSaveOutcome.incomplete:
        setState(() => _message = null);
      case GroupSaveOutcome.busy:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final cp = context.cp;
    final strings = context.strings.groupEntry;
    final word = event.words.one('group');
    final state = ref.watch(groupEntryProvider(_args));
    final draft = state.draft;
    final check = state.check;
    final readsPrivate = _readsPrivate;
    final allFields =
        ref.watch(eventFieldsProvider(event.id)).value ?? const <CustomField>[];
    List<CustomField> visible(FieldScope scope) => [
      for (final f in allFields)
        if (f.scope == scope && (readsPrivate || !f.isPrivate)) f,
    ];
    final groupFields = visible(FieldScope.group);
    final personFields = visible(FieldScope.participant);
    final categories = categoriesOf(event.settings);
    final start = event.displayStart ?? DateTime.now();
    final title = draft.isNewGroup
        ? strings.newTitle(word)
        : strings.addToTitle(_group?.name ?? draft.groupName);
    final saving = state.saving;

    Widget scaffold(Widget body, {Widget? bottom}) => PopScope(
      canPop: _finished || saving || !state.hasEntries,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context) && mounted) {
          setState(() => _finished = true);
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: CpTopBar(
          title: title,
          leadingIcon: CpIcons.actionClose,
          leadingTooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          leadingKey: const Key('people.groupEntry.close'),
          onLeading: () => Navigator.of(context).maybePop(),
        ),
        body: body,
        bottomNavigationBar: bottom,
      ),
    );

    if (widget.groupId != null && _group == null) {
      return scaffold(
        _loadFailed
            ? CpErrorState(
                title: context.strings.people.loadFailed,
                retryLabel: context.strings.people.retry,
                onRetry: _loadGroup,
                retryKey: const Key('people.groupEntry.retryLoad'),
              )
            : CpLoadingState(
                key: const Key('people.groupEntry.loading'),
                semanticLabel: title,
              ),
      );
    }
    if (_loadingGroup) return scaffold(const SizedBox.shrink());

    final missing = check?.missingCount ?? 0;
    final note =
        _message ??
        (check == null || check.ok
            ? null
            : check.noPeople
            ? strings.addAtLeastOne
            : missing > 0
            ? strings.missingCount(missing)
            : null);

    final groupCard = CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          if (draft.isNewGroup)
            CpTextField(
              label: strings.groupName(word),
              fieldKey: const Key('people.groupEntry.groupName'),
              controller: _groupName,
              required: true,
              requiredLabel: strings.required,
              maxLength: 120,
              error: check?.groupNameMissing == true
                  ? strings.nameRequired
                  : null,
              onChanged: (v) => _edit((d) => _withGroup(d, name: v)),
            )
          else
            Text(
              _group?.name ?? draft.groupName,
              key: const Key('people.groupEntry.groupNameShown'),
              style: cp.type.titleLarge.copyWith(color: cp.colors.text),
            ),
          if (groupFields.isNotEmpty)
            Text(
              strings.groupQuestions(word),
              style: cp.type.labelSmall.copyWith(color: cp.colors.textMuted),
            ),
          for (final field in groupFields)
            AnswerInput(
              key: Key('people.groupEntry.group.question.${field.id}'),
              field: field,
              keyPrefix: 'people.groupEntry.group',
              value: field.isPrivate
                  ? draft.groupPrivateAnswers[field.id]
                  : draft.groupAnswers[field.id],
              showError: check?.groupMissing.contains(field.id) ?? false,
              onChanged: (v) => _groupAnswer(field, v),
            ),
        ],
      ),
    );

    final body = ListView(
      key: const Key('people.groupEntry'),
      padding: EdgeInsets.fromLTRB(
        cp.space.lg,
        cp.space.sm,
        cp.space.lg,
        cp.space.xxl,
      ),
      children: [
        ContentMaxWidth(
          maxWidth: cp.sizes.phoneColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.lg,
            children: [
              groupCard,
              CpSectionHeader(
                title: strings.peopleHeading,
                trailingText: strings.peopleCount(draft.toSave.length),
              ),
              for (var i = 0; i < draft.people.length; i++)
                PersonCard(
                  key: ValueKey(draft.people[i].id),
                  number: i + 1,
                  person: draft.people[i],
                  keyPrefix: 'people.groupEntry.person.$i',
                  fields: personFields,
                  categories: categories,
                  eventStart: start,
                  check: check?.people[draft.people[i].id],
                  previousName: i > 0 ? draft.people[i - 1].name : null,
                  onChanged: (p) => _edit((d) => _withPerson(d, p)),
                  onRemove: draft.people.length > 1
                      ? () => _edit((d) => d.removePerson(draft.people[i].id))
                      : null,
                  onCopyPrevious: i > 0
                      ? () => _edit(
                          (d) => d.copyFromPrevious(
                            draft.people[i].id,
                            readsPrivate: readsPrivate,
                          ),
                        )
                      : null,
                ),
              if (draft.canAddPerson)
                CpButton.secondary(
                  key: const Key('people.groupEntry.addPerson'),
                  icon: CpIcons.actionAdd,
                  label: strings.addAnotherPerson,
                  expand: true,
                  onPressed: () => _edit((d) => d.addPerson(newRecordId())),
                )
              else
                Text(
                  strings.maxPeople,
                  key: const Key('people.groupEntry.max'),
                  textAlign: TextAlign.center,
                  style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
                ),
            ],
          ),
        ),
      ],
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
            padding: EdgeInsets.fromLTRB(
              cp.space.lg,
              cp.space.md,
              cp.space.lg,
              cp.space.md,
            ),
            child: Row(
              spacing: cp.space.md,
              children: [
                Expanded(
                  child: note == null
                      ? const SizedBox.shrink()
                      : KeyedSubtree(
                          key: const Key('people.groupEntry.message'),
                          child: CpFieldError(note),
                        ),
                ),
                Flexible(
                  child: CpButton(
                    key: const Key('people.groupEntry.save'),
                    label: draft.isNewGroup
                        ? strings.save(word)
                        : strings.saveAdditions,
                    busy: saving,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return scaffold(body, bottom: saveBar);
  }
}
