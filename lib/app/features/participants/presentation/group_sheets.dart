import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/chosen_people_list.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:crewpoint_app/app/features/participants/presentation/field_answer_input.dart';

/// A new group's ID, picked once so a retry saves the same group.
String newGroupId() {
  final random = Random();
  return List.generate(
    20,
    (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[random.nextInt(36)],
  ).join();
}

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
  }) => showModalBottomSheet<GroupModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
    final words = widget.event.words;
    final strings = context.strings.people;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        key: const Key('people.groupPicker'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          TextField(
            key: const Key('people.groupPicker.search'),
            controller: _search,
            onChanged: _onSearch,
            autofocus: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(AppIcons.actionSearch),
              hintText: strings.groupSearchHint(words.other('group')),
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.allowCreate)
            ListTile(
              key: const Key('people.groupPicker.new'),
              leading: _creating
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.actionAdd),
              title: Text(strings.newGroup(words.one('group'))),
              onTap: _creating ? null : _create,
            ),
          Flexible(
            child: FutureBuilder<List<GroupModel>>(
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
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final groups = snap.data!;
                if (groups.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      strings.noGroupsFound(words.other('group')),
                      key: const Key('people.groupPicker.none'),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView(
                  shrinkWrap: true,
                  children: [
                    for (final g in groups)
                      ListTile(
                        key: Key('people.groupPicker.${g.id}'),
                        leading: const Icon(AppIcons.members),
                        title: Text(g.name),
                        onTap: () => Navigator.of(context).pop(g),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  final formKey = GlobalKey<FormState>();
  final strings = context.strings.people;
  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          key: const Key('people.groupName'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          validator: (v) {
            final name = v?.trim() ?? '';
            if (name.isEmpty) return strings.nameRequired;
            if (name.length > 120) return strings.nameTooLong(120);
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(context.strings.roles.cancel),
        ),
        TextButton(
          key: const Key('people.groupName.save'),
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(dialog).pop(controller.text.trim());
            }
          },
          child: Text(strings.save),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// What managing a group changed, for the roster to follow.
class GroupSheetResult {
  const GroupSheetResult({this.group, this.deleted = false});

  final GroupModel? group;
  final bool deleted;
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
  }) => showModalBottomSheet<GroupSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => GroupSheet(event: event, group: group, manage: manage),
  );

  @override
  ConsumerState<GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends ConsumerState<GroupSheet> {
  late final TextEditingController _name;
  late Set<String> _adults;
  late GroupModel _group;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _name = TextEditingController(text: _group.name);
    _adults = {..._group.adultUids};
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
      _group = GroupModel(id: _group.id, name: _group.name, adultUids: uids);
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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.people;
    final words = widget.event.words;
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: ListView(
          key: const Key('people.group'),
          shrinkWrap: true,
          children: [
            if (!widget.manage)
              Text(_group.name, style: theme.textTheme.titleMedium),
            _GroupAnswers(event: widget.event, groupId: _group.id),
            if (widget.manage) ...[
              TextField(
                key: const Key('people.group.name'),
                controller: _name,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: strings.groupNameLabel(words.one('group')),
                  border: const OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('people.group.rename'),
                  onPressed: _busy ? null : _rename,
                  child: Text(strings.rename),
                ),
              ),
              Text(strings.adultsHeading, style: theme.textTheme.titleSmall),
              Text(
                strings.adultsHelp(words.one('group')),
                style: theme.textTheme.bodySmall,
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
              OverflowBar(
                alignment: MainAxisAlignment.spaceBetween,
                overflowAlignment: OverflowBarAlignment.end,
                children: [
                  TextButton.icon(
                    key: const Key('people.group.delete'),
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(AppIcons.actionDelete),
                    label: Text(context.strings.roles.delete),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                  FilledButton(
                    key: const Key('people.group.saveAdults'),
                    onPressed: _busy ? null : _saveAdults,
                    child: Text(strings.save),
                  ),
                ],
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('people.group.close'),
                onPressed: _busy
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(GroupSheetResult(group: _group)),
                child: Text(context.strings.roles.cancel),
              ),
            ),
          ],
        ),
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
    final strings = context.strings.fields;
    final theme = Theme.of(context);
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
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
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
        spacing: AppSpacing.md,
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
            Text(
              _error!,
              key: const Key('people.group.answersError'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('people.group.saveAnswers'),
              onPressed: _busy ? null : save,
              child: Text(strings.save),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
