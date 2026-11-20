import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/chosen_people_list.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/crew.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/member.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';

/// Matches `MAX_NAME` in `functions/src/events/crews.ts`.
const _maxName = 60;

/// Whether the viewer may open the Crews screen: anyone who manages members
/// or tasks. Only `members.manage` may change crews.
bool canViewCrews(EventModel event, String uid) =>
    event.can(uid, 'members.manage') || event.can(uid, 'tasks.manage');

/// The event's crews and who is in each (Req 33, route `crews`).
class CrewsScreen extends ConsumerWidget {
  const CrewsScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.crews;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final canEdit = event.can(me, 'members.manage');
    final crewWord = event.words.one('crew');

    final Widget body;
    if (!canViewCrews(event, me)) {
      body = const NoAccessView();
    } else {
      final members =
          ref.watch(eventMembersProvider(event.id)).value ??
          const <MemberModel>[];
      body = switch (ref.watch(eventCrewsProvider(event.id))) {
        AsyncValue(:final value?) =>
          value.isEmpty
              ? CpEmptyState(
                  key: const Key('crews.empty'),
                  icon: CpIcons.members,
                  title: strings.emptyTitle(event.words.other('crew')),
                  message: canEdit ? strings.emptyHint : strings.readOnly,
                  actionLabel: canEdit ? strings.newCrew(crewWord) : null,
                  actionKey: const Key('crews.empty.add'),
                  onAction: canEdit
                      ? () => showCrewNameDialog(context, ref, event: event)
                      : null,
                )
              : _CrewList(
                  event: event,
                  crews: value,
                  members: members,
                  canEdit: canEdit,
                ),
        AsyncValue(error: != null) => LoadFailedView(
          onRetry: () => ref.invalidate(eventCrewsProvider(event.id)),
        ),
        _ => CpLoadingState.rows(
          key: const Key('crews.loading'),
          semanticLabel: event.words.other('crew'),
        ),
      };
    }

    return AdminScaffold(
      title: event.words.other('crew'),
      actions: [
        if (canEdit)
          CpTopBarAction(
            key: const Key('crews.new'),
            icon: CpIcons.actionAdd,
            tooltip: strings.newCrew(crewWord),
            primary: true,
            onPressed: () => showCrewNameDialog(context, ref, event: event),
          ),
      ],
      body: body,
    );
  }
}

class _CrewList extends ConsumerWidget {
  const _CrewList({
    required this.event,
    required this.crews,
    required this.members,
    required this.canEdit,
  });

  final EventModel event;
  final List<CrewModel> crews;
  final List<MemberModel> members;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.crews;
    return AdminList(
      listKey: const Key('crews.body'),
      children: [
        if (!canEdit)
          AdminNote(
            strings.readOnly,
            key: const Key('crews.readOnly'),
            icon: CpIcons.lock,
          ),
        CpCard(
          child: CpRowGroup(
            children: [
              for (final crew in crews)
                Row(
                  children: [
                    Expanded(
                      child: CpListRow(
                        key: Key('crews.tile.${crew.id}'),
                        title: crew.name,
                        subtitle: () {
                          final count = members
                              .where((m) => m.crewIds.contains(crew.id))
                              .length;
                          return count == 0
                              ? strings.noMembers
                              : event.words.count('member', count);
                        }(),
                        // The menu sits beside the row, so it stays its own
                        // button for screen readers.
                        trailing: canEdit ? const SizedBox.shrink() : null,
                        onTap: canEdit
                            ? () => _CrewMembersSheet.show(
                                context,
                                event: event,
                                crew: crew,
                                members: members,
                              )
                            : null,
                      ),
                    ),
                    if (canEdit)
                      PopupMenuButton<String>(
                        key: Key('crews.tile.${crew.id}.menu'),
                        tooltip: strings.crewOptions,
                        icon: Icon(
                          CpIcons.actionMore,
                          size: cp.sizes.iconMd,
                          color: cp.colors.textMuted,
                        ),
                        onSelected: (action) => action == 'rename'
                            ? showCrewNameDialog(
                                context,
                                ref,
                                event: event,
                                crew: crew,
                              )
                            : _delete(context, ref, crew),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            key: Key('crews.tile.${crew.id}.rename'),
                            value: 'rename',
                            child: Text(strings.rename),
                          ),
                          PopupMenuItem(
                            key: Key('crews.tile.${crew.id}.delete'),
                            value: 'delete',
                            child: Text(
                              strings.delete,
                              style: TextStyle(color: cp.colors.overdue),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CrewModel crew,
  ) async {
    final strings = context.strings.crews;
    final confirmed = await confirmAction(
      context,
      title: strings.deleteTitle(crew.name),
      body: strings.deleteBody(event.words.one('crew')),
      action: strings.delete,
      confirmKey: const Key('crews.deleteConfirm'),
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final errors = context.strings.errors;
    try {
      await ref
          .read(memberCallsProvider)
          .deleteCrew(eventId: event.id, crewId: crew.id);
      messenger.showSnackBar(SnackBar(content: Text(strings.deleted)));
    } catch (e, st) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userMessageFor(
              e,
              stackTrace: st,
              strings: errors,
              fallback: strings.deleteFailed,
            ),
          ),
        ),
      );
    }
  }
}

/// Asks for a crew's name, then creates it, or renames [crew]. The dialog
/// stays open with the name kept if saving fails.
Future<void> showCrewNameDialog(
  BuildContext context,
  WidgetRef ref, {
  required EventModel event,
  CrewModel? crew,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CrewNameDialog(event: event, crew: crew),
  );
}

class _CrewNameDialog extends ConsumerStatefulWidget {
  const _CrewNameDialog({required this.event, this.crew});

  final EventModel event;
  final CrewModel? crew;

  @override
  ConsumerState<_CrewNameDialog> createState() => _CrewNameDialogState();
}

class _CrewNameDialogState extends ConsumerState<_CrewNameDialog> {
  late final _name = TextEditingController(text: widget.crew?.name ?? '');
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  /// Picked once for a new crew, so a retry saves the same crew.
  String? _newId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _idFor(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final short = slug.length > 30 ? slug.substring(0, 30) : slug;
    final suffix = Random().nextInt(1 << 20).toRadixString(36);
    return '${short.isEmpty ? 'crew' : short}-$suffix';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final strings = context.strings.crews;
    final errors = context.strings.errors;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _name.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(memberCallsProvider)
          .saveCrew(
            eventId: widget.event.id,
            crewId: widget.crew?.id ?? (_newId ??= _idFor(name)),
            name: name,
          );
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(strings.saved)));
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = userMessageFor(
          e,
          stackTrace: st,
          strings: errors,
          fallback: strings.saveFailed,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.crews;
    final crewWord = widget.event.words.one('crew');
    return CpDialog(
      title: widget.crew == null ? strings.newCrew(crewWord) : strings.rename,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: context.cp.space.sm,
          children: [
            CpTextField(
              fieldKey: const Key('crews.name'),
              label: strings.nameLabel,
              controller: _name,
              autofocus: true,
              enabled: !_busy,
              maxLength: _maxName,
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return strings.nameRequired;
                if (name.length > _maxName) {
                  return strings.nameTooLong(_maxName);
                }
                return null;
              },
              onSubmitted: (_) => _save(),
            ),
            if (_error != null)
              KeyedSubtree(
                key: const Key('crews.nameError'),
                child: CpFieldError(_error!),
              ),
          ],
        ),
      ),
      actions: [
        CpButton.text(
          label: strings.cancel,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        CpButton(
          key: const Key('crews.nameSave'),
          label: widget.crew == null ? strings.create : strings.save,
          busy: _busy,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}

/// Picks who is in a crew. Leaving with changes asks first, and a failed save
/// keeps the choices.
class _CrewMembersSheet extends ConsumerStatefulWidget {
  const _CrewMembersSheet({
    required this.event,
    required this.crew,
    required this.members,
  });

  final EventModel event;
  final CrewModel crew;
  final List<MemberModel> members;

  static Future<void> show(
    BuildContext context, {
    required EventModel event,
    required CrewModel crew,
    required List<MemberModel> members,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Closing goes through Cancel or Save, so changes are never lost to a
      // stray swipe.
      isDismissible: false,
      enableDrag: false,
      builder: (_) =>
          _CrewMembersSheet(event: event, crew: crew, members: members),
    );
  }

  @override
  ConsumerState<_CrewMembersSheet> createState() => _CrewMembersSheetState();
}

class _CrewMembersSheetState extends ConsumerState<_CrewMembersSheet> {
  late final Set<String> _saved = {
    for (final m in widget.members)
      if (m.crewIds.contains(widget.crew.id)) m.uid,
  };
  late Set<String> _picked = {..._saved};
  bool _busy = false;
  String? _error;

  bool get _dirty =>
      _picked.length != _saved.length || !_picked.containsAll(_saved);

  Future<void> _close() async {
    final navigator = Navigator.of(context);
    if (_dirty && !await confirmDiscard(context)) return;
    navigator.pop();
  }

  Future<void> _save() async {
    final strings = context.strings.crews;
    final errors = context.strings.errors;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(memberCallsProvider)
          .setCrewMembers(
            eventId: widget.event.id,
            crewId: widget.crew.id,
            uids: _picked.toList()..sort(),
          );
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(strings.membersSaved)));
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = userMessageFor(
          e,
          stackTrace: st,
          strings: errors,
          fallback: strings.saveFailed,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.crews;
    return PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              Padding(
                padding: EdgeInsets.all(cp.space.lg),
                child: Semantics(
                  header: true,
                  child: Text(
                    strings.membersTitle(widget.crew.name),
                    style: cp.type.titleLarge.copyWith(color: cp.colors.text),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  key: const Key('crews.members.list'),
                  padding: EdgeInsets.symmetric(horizontal: cp.space.lg),
                  // Chosen by name search, so a large event never lists
                  // everyone (Req 43a).
                  child: ChosenPeopleList(
                    eventId: widget.event.id,
                    words: widget.event.words,
                    keyPrefix: 'crews.members',
                    chosen: _picked,
                    enabled: !_busy,
                    onChanged: (uids) => setState(() => _picked = uids),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: cp.space.lg),
                  child: KeyedSubtree(
                    key: const Key('crews.members.error'),
                    child: CpFieldError(_error!),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(cp.space.lg),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: cp.space.sm,
                  runSpacing: cp.space.sm,
                  children: [
                    CpButton.text(
                      key: const Key('crews.members.cancel'),
                      label: strings.cancel,
                      onPressed: _busy ? null : _close,
                    ),
                    CpButton(
                      key: const Key('crews.members.save'),
                      label: strings.save,
                      busy: _busy,
                      onPressed: _busy || !_dirty ? null : _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
