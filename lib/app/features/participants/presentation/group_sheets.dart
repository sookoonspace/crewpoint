import 'dart:async';

import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/chosen_people_list.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/group_draft.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:crewpoint_app/app/features/participants/presentation/field_answer_input.dart';

/// A new group's ID, picked once so a retry saves the same group.
String newGroupId() => newRecordId();

/// Picks a group by searching its name (Req 43), so it works at thousands of
/// groups. With [allowCreate], offers a new group too. With [onlyIds], lists
/// just those, for a linked adult choosing among their own.
class GroupPickerSheet extends ConsumerStatefulWidget {
  const GroupPickerSheet({
    super.key,
    required this.event,
    this.allowCreate = false,
    this.onlyIds,
  });

  final EventModel event;
  final bool allowCreate;
  final List<String>? onlyIds;

  static Future<GroupModel?> show(
    BuildContext context, {
    required EventModel event,
    bool allowCreate = false,
    List<String>? onlyIds,
  }) => showCpSheet<GroupModel>(
    context: context,
    builder: (_) => GroupPickerSheet(
      event: event,
      allowCreate: allowCreate,
      onlyIds: onlyIds,
    ),
  );

  @override
  ConsumerState<GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends ConsumerState<GroupPickerSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  late Future<List<GroupModel>> _results;
  bool _creating = false;
  String? _newId;

  @override
  void initState() {
    super.initState();
    _results = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<List<GroupModel>> _load() async {
    final repo = ref.read(participantRepositoryProvider);
    final ids = widget.onlyIds;
    if (ids != null) {
      final found = await repo.groupsByIds(widget.event.id, ids);
      final q = _search.text.trim().toLowerCase();
      return [
        for (final g in found.values)
          if (g.name.toLowerCase().startsWith(q)) g,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return repo.searchGroups(widget.event.id, _search.text);
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => setState(() {
        _results = _load();
      }),
    );
  }

  Future<void> _create() async {
    final words = widget.event.words;
    final strings = context.strings.people;
    final name = await _askName(
      context,
      title: strings.newGroup(words.one('group')),
      label: strings.newGroupName(words.one('group')),
      initial: _search.text.trim(),
    );
    if (name == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final id = _newId ??= newGroupId();
    setState(() => _creating = true);
    try {
      await ref
          .read(memberCallsProvider)
          .saveGroup(eventId: widget.event.id, groupId: id, name: name);
      navigator.pop(GroupModel(id: id, name: name));
    } catch (e, st) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userMessageFor(
              e,
              stackTrace: st,
              strings: context.strings.errors,
              fallback: strings.groupSaveFailed,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final words = widget.event.words;
    final strings = context.strings.people;
    return Column(
      key: const Key('people.groupPicker'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.md,
      children: [
        CpSearchField(
          fieldKey: const Key('people.groupPicker.search'),
          controller: _search,
          onChanged: _onSearch,
          autofocus: true,
          hint: strings.groupSearchHint(words.other('group')),
        ),
        if (widget.allowCreate)
          CpCard(
            child: CpListRow(
              key: const Key('people.groupPicker.new'),
              leading: Icon(
                CpIcons.actionAdd,
                size: cp.sizes.iconMd,
                color: cp.colors.accent,
              ),
              title: strings.newGroup(words.one('group')),
              trailing: _creating
                  ? CpLoadingState(
                      semanticLabel: strings.newGroup(words.one('group')),
                    )
                  : null,
              onTap: _creating ? null : _create,
            ),
          ),
        FutureBuilder<List<GroupModel>>(
          future: _results,
          builder: (context, snap) {
            if (snap.hasError) {
              return LoadFailedView(
                onRetry: () => setState(() {
                  _results = _load();
                }),
              );
            }
            if (!snap.hasData) {
              return CpLoadingState.rows(
                semanticLabel: words.other('group'),
                rows: 3,
              );
            }
            final groups = snap.data!;
            if (groups.isEmpty) {
              return Text(
                strings.noGroupsFound(words.other('group')),
                key: const Key('people.groupPicker.none'),
                textAlign: TextAlign.center,
                style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
              );
            }
            return CpCard(
              child: CpRowGroup(
                children: [
                  for (final g in groups)
                    CpListRow(
                      key: Key('people.groupPicker.${g.id}'),
                      leading: Icon(
                        CpIcons.members,
                        size: cp.sizes.iconMd,
                        color: cp.colors.textMuted,
                      ),
                      title: g.name,
                      onTap: () => Navigator.of(context).pop(g),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Asks for a group's name. The prompt owns its text controller, so it
/// lives until the dialog has finished closing (#185).
Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) {
  final strings = context.strings.people;
  return showCpTextPrompt(
    context: context,
    title: title,
    label: label,
    initial: initial,
    confirmLabel: strings.save,
    cancelLabel: context.strings.roles.cancel,
    fieldKey: const Key('people.groupName'),
    confirmKey: const Key('people.groupName.save'),
    validator: (v) {
      final name = v?.trim() ?? '';
      if (name.isEmpty) return strings.nameRequired;
      if (name.length > 120) return strings.nameTooLong(120);
      return null;
    },
  );
}

/// What managing a group changed, for the roster to follow.
class GroupSheetResult {
  const GroupSheetResult({
    this.group,
    this.deleted = false,
    this.addPeople = false,
    this.editAnswers = false,
  });

  final GroupModel? group;
  final bool deleted;

  /// "Edit answers" was chosen: open the group screen editing [group].
  final bool editAnswers;

  /// "Add people" was chosen: open the group screen on [group].
  final bool addPeople;
}

/// A group's custom field answers, and with [manage] (`participants.edit`)
/// its name, linked adults, and deleting it when empty. A linked adult opens
/// it without [manage], for their own group's answers only.
class GroupSheet extends ConsumerStatefulWidget {
  const GroupSheet({
    super.key,
    required this.event,
    required this.group,
    this.manage = true,
  });

  final EventModel event;
  final GroupModel group;
  final bool manage;

  static Future<GroupSheetResult?> show(
    BuildContext context, {
    required EventModel event,
    required GroupModel group,
    bool manage = true,
  }) => showCpSheet<GroupSheetResult>(
    context: context,
    title: group.name,
    builder: (_) => GroupSheet(event: event, group: group, manage: manage),
  );

  @override
  ConsumerState<GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends ConsumerState<GroupSheet> {
  late final TextEditingController _name;
  late Set<String> _adults;
  late Set<String> _invited;
  late GroupModel _group;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _name = TextEditingController(text: _group.name);
    _adults = {..._group.adultUids};
    _invited = {..._group.invitedTo};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.strings.people;
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e, st) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userMessageFor(
              e,
              stackTrace: st,
              strings: context.strings.errors,
              fallback: strings.groupSaveFailed,
            ),
          ),
        ),
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename() async {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 120) return;
    try {
      await _run(
        () => ref
            .read(memberCallsProvider)
            .saveGroup(
              eventId: widget.event.id,
              groupId: _group.id,
              name: name,
            ),
        context.strings.people.groupSaved,
      );
      _group = GroupModel(
        id: _group.id,
        name: name,
        adultUids: _group.adultUids,
        fields: _group.fields,
        invitedTo: _group.invitedTo,
      );
    } catch (_) {}
  }

  Future<void> _saveAdults() async {
    final uids = _adults.toList()..sort();
    try {
      await _run(
        () => ref
            .read(memberCallsProvider)
            .setGroupAdults(
              eventId: widget.event.id,
              groupId: _group.id,
              uids: uids,
            ),
        context.strings.people.groupSaved,
      );
      _group = GroupModel(
        id: _group.id,
        name: _group.name,
        adultUids: uids,
        fields: _group.fields,
        invitedTo: _group.invitedTo,
      );
    } catch (_) {}
  }

  /// The sessions the whole group is invited to (Req 50).
  Future<void> _saveInvitations() async {
    final ids = _invited.toList()..sort();
    try {
      await _run(
        () => ref
            .read(participantRepositoryProvider)
            .saveGroupInvitations(widget.event.id, _group.id, ids),
        context.strings.agenda.groupInvitationsSaved,
      );
      _group = GroupModel(
        id: _group.id,
        name: _group.name,
        adultUids: _group.adultUids,
        fields: _group.fields,
        invitedTo: ids,
      );
    } catch (_) {}
  }

  Future<void> _delete() async {
    final strings = context.strings.people;
    final words = widget.event.words;
    final navigator = Navigator.of(context);
    final confirmed = await confirmAction(
      context,
      title: strings.deleteGroupTitle(_group.name),
      body: strings.deleteGroupBody(words.one('group')),
      action: context.strings.roles.delete,
      confirmKey: const Key('people.group.deleteConfirm'),
    );
    if (!confirmed || !mounted) return;
    try {
      await _run(
        () => ref
            .read(memberCallsProvider)
            .deleteGroup(eventId: widget.event.id, groupId: _group.id),
        strings.groupDeleted,
      );
      navigator.pop(const GroupSheetResult(deleted: true));
    } catch (_) {}
  }

  List<Widget> _invitations() {
    final strings = context.strings.agenda;
    final sessions = [
      for (final s
          in ref.watch(sessionListProvider(widget.event.id)).value ??
              const <SessionModel>[])
        if (!s.hidden) s,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (sessions.isEmpty) return const [];
    return [
      CpChoiceChips<String>(
        label: strings.groupInvitations,
        help: strings.groupInvitationsHelp,
        multiple: true,
        choices: [
          for (final s in sessions)
            CpChoice(s.id, s.title, key: Key('people.group.invite.${s.id}')),
        ],
        selected: _invited,
        onChanged: _busy
            ? null
            : (ids) => setState(
                () => _invited
                  ..clear()
                  ..addAll(ids),
              ),
      ),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: CpButton.secondary(
          key: const Key('people.group.saveInvitations'),
          label: context.strings.people.save,
          onPressed: _busy ? null : _saveInvitations,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.people;
    final words = widget.event.words;
    Widget heading(String title, String help) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.xs,
      children: [
        Text(title, style: cp.type.titleSmall.copyWith(color: cp.colors.text)),
        Text(
          help,
          style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
        ),
      ],
    );
    return PopScope(
      canPop: !_busy,
      child: Column(
        key: const Key('people.group'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          if (widget.manage)
            Wrap(
              spacing: cp.space.sm,
              runSpacing: cp.space.sm,
              children: [
                CpButton.secondary(
                  key: const Key('people.group.addPeople'),
                  icon: CpIcons.memberAdd,
                  label: context.strings.groupEntry.addPeople(
                    words.other('participant'),
                  ),
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(GroupSheetResult(group: _group, addPeople: true)),
                ),
                CpButton.secondary(
                  key: const Key('people.group.editAnswers'),
                  icon: CpIcons.actionEdit,
                  label: context.strings.groupEntry.editAnswers,
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(
                          GroupSheetResult(group: _group, editAnswers: true),
                        ),
                ),
              ],
            ),
          _GroupAnswers(event: widget.event, groupId: _group.id),
          if (widget.manage) ...[
            CpTextField(
              fieldKey: const Key('people.group.name'),
              controller: _name,
              enabled: !_busy,
              label: strings.groupNameLabel(words.one('group')),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CpButton.secondary(
                key: const Key('people.group.rename'),
                label: strings.rename,
                onPressed: _busy ? null : _rename,
              ),
            ),
            heading(
              strings.adultsHeading,
              strings.adultsHelp(words.one('group')),
            ),
            // Chosen by name search, so a large event never lists
            // everyone (Req 43a).
            ChosenPeopleList(
              eventId: widget.event.id,
              words: words,
              keyPrefix: 'people.group.adult',
              chosen: _adults,
              enabled: !_busy,
              emptyText: strings.noAdultsYet,
              onChanged: (uids) => setState(
                () => _adults
                  ..clear()
                  ..addAll(uids),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CpButton(
                key: const Key('people.group.saveAdults'),
                label: strings.save,
                busy: _busy,
                onPressed: _saveAdults,
              ),
            ),
            if (widget.event.isModuleOn('schedule')) ..._invitations(),
          ],
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: cp.space.sm,
            overflowSpacing: cp.space.sm,
            children: [
              if (widget.manage)
                CpButton.text(
                  key: const Key('people.group.delete'),
                  icon: CpIcons.actionDelete,
                  label: strings.deleteGroup(words.one('group')),
                  onPressed: _busy ? null : _delete,
                ),
              CpButton.text(
                key: const Key('people.group.close'),
                label: context.strings.roles.cancel,
                onPressed: _busy
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(GroupSheetResult(group: _group)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A group's custom field answers (Req 41): standard ones on the group, and
/// private ones in its private document, shown only to those who may read
/// them.
class _GroupAnswers extends ConsumerStatefulWidget {
  const _GroupAnswers({required this.event, required this.groupId});

  final EventModel event;
  final String groupId;

  @override
  ConsumerState<_GroupAnswers> createState() => _GroupAnswersState();
}

class _GroupAnswersState extends ConsumerState<_GroupAnswers> {
  final _formKey = GlobalKey<FormState>();
  Map<String, Object?>? _standard;
  Map<String, Object?>? _private;
  bool _privateAsked = false;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.fields;
    final event = widget.event;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final own =
        ref.watch(myMemberProvider(event.id)).value?.groupIds ?? const [];
    final readsPrivate =
        event.can(me, 'participants.readPrivate') ||
        own.contains(widget.groupId);
    final fields = <CustomField>[
      for (final f
          in ref.watch(eventFieldsProvider(event.id)).value ??
              const <CustomField>[])
        if (f.scope == FieldScope.group && (!f.isPrivate || readsPrivate)) f,
    ];
    if (fields.isEmpty) return const SizedBox.shrink();

    final group = ref.watch(
      groupsByIdProvider((eventId: event.id, ids: widget.groupId)),
    );
    _standard ??= group.value?[widget.groupId]?.fields == null
        ? null
        : {...group.value![widget.groupId]!.fields};
    if (readsPrivate && !_privateAsked) {
      _privateAsked = true;
      ref
          .read(participantRepositoryProvider)
          .readGroupPrivate(event.id, widget.groupId)
          .then((v) {
            if (mounted) setState(() => _private = {...?v});
          }, onError: (_) {});
    }
    if (_standard == null || (readsPrivate && _private == null)) {
      return CpLoadingState(semanticLabel: strings.save);
    }

    Future<void> save() async {
      if (!_formKey.currentState!.validate()) return;
      final messenger = ScaffoldMessenger.of(context);
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await ref
            .read(participantRepositoryProvider)
            .saveGroupAnswers(
              event.id,
              widget.groupId,
              standard: _standard!,
              private: readsPrivate ? _private : null,
              definitions: fields,
            );
        messenger.showSnackBar(SnackBar(content: Text(strings.saved)));
      } catch (_) {
        if (mounted) setState(() => _error = strings.saveFailed);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          for (final f in fields)
            FieldAnswerInput(
              field: f,
              value: (f.isPrivate ? _private : _standard)![f.id],
              enabled: !_busy,
              onChanged: (v) => setState(() {
                final target = f.isPrivate ? _private! : _standard!;
                if (v == null) {
                  target.remove(f.id);
                } else {
                  target[f.id] = v;
                }
              }),
            ),
          if (_error != null)
            CpFieldError(_error!, key: const Key('people.group.answersError')),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: CpButton(
              key: const Key('people.group.saveAnswers'),
              label: strings.save,
              busy: _busy,
              onPressed: save,
            ),
          ),
          Divider(height: cp.space.lg, color: cp.colors.border),
        ],
      ),
    );
  }
}
