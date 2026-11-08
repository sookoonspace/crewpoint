import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
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
      body = ref
          .watch(eventCrewsProvider(event.id))
          .when(
            loading: () => const Center(
              child: CircularProgressIndicator(key: Key('crews.loading')),
            ),
            error: (_, _) => LoadFailedView(
              onRetry: () => ref.invalidate(eventCrewsProvider(event.id)),
            ),
            data: (crews) => crews.isEmpty
                ? _Empty(event: event, canEdit: canEdit)
                : _CrewList(
                    event: event,
                    crews: crews,
                    members: members,
                    canEdit: canEdit,
                  ),
          );
    }

    return Scaffold(
      appBar: AppBar(title: Text(event.words.other('crew')), elevation: 0),
      body: body,
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              key: const Key('crews.new'),
              onPressed: () => showCrewNameDialog(context, ref, event: event),
              icon: const Icon(AppIcons.actionAdd),
              label: Text(strings.newCrew(crewWord)),
            )
          : null,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.event, required this.canEdit});

  final EventModel event;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.crews;
    final theme = Theme.of(context);
    return Center(
      key: const Key('crews.empty'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: .min,
          spacing: AppSpacing.md,
          children: [
            Icon(
              AppIcons.members,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            Text(
              strings.emptyTitle(event.words.other('crew')),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              canEdit ? strings.emptyHint : strings.readOnly,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
    final strings = context.strings.crews;
    final theme = Theme.of(context);
    return ContentMaxWidth(
      key: const Key('crews.body'),
      maxWidth: 720,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Breakpoints.screenHorizontalPadding(context),
          AppSpacing.md,
          Breakpoints.screenHorizontalPadding(context),
          AppSpacing.xxl * 3,
        ),
        children: [
          if (!canEdit)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                strings.readOnly,
                key: const Key('crews.readOnly'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final crew in crews)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              child: ListTile(
                key: Key('crews.tile.${crew.id}'),
                minTileHeight: 56,
                title: Text(crew.name),
                subtitle: Text(() {
                  final count = members
                      .where((m) => m.crewIds.contains(crew.id))
                      .length;
                  return count == 0
                      ? strings.noMembers
                      : event.words.count('member', count);
                }()),
                onTap: canEdit
                    ? () => _CrewMembersSheet.show(
                        context,
                        event: event,
                        crew: crew,
                        members: members,
                      )
                    : null,
                trailing: canEdit
                    ? PopupMenuButton<String>(
                        key: Key('crews.tile.${crew.id}.menu'),
                        tooltip: strings.crewOptions,
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
                            child: Text(strings.delete),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
        ],
      ),
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
    return AlertDialog(
      title: Text(
        widget.crew == null ? strings.newCrew(crewWord) : strings.rename,
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            TextFormField(
              key: const Key('crews.name'),
              controller: _name,
              autofocus: true,
              enabled: !_busy,
              maxLength: _maxName,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: strings.nameLabel),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return strings.nameRequired;
                if (name.length > _maxName) {
                  return strings.nameTooLong(_maxName);
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('crews.nameError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('crews.nameSave'),
          onPressed: _busy ? null : _save,
          child: Text(widget.crew == null ? strings.create : strings.save),
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
            uids: [
              for (final uid in widget.event.memberIds)
                if (_picked.contains(uid)) uid,
            ],
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
    final strings = context.strings.crews;
    final memberIds = widget.event.memberIds;
    final users =
        ref.watch(usersByIdProvider(usersByIds(memberIds))).value ?? const {};
    String nameOf(String uid) {
      final user = users[uid];
      if (user?.displayName?.isNotEmpty ?? false) return user!.displayName!;
      if (user?.email.isNotEmpty ?? false) return user!.email;
      return widget.event.words.one('member');
    }

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
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  strings.membersTitle(widget.crew.name),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: ListView(
                  key: const Key('crews.members.list'),
                  shrinkWrap: true,
                  children: [
                    for (final uid in memberIds)
                      CheckboxListTile(
                        key: Key('crews.members.$uid'),
                        value: _picked.contains(uid),
                        onChanged: _busy
                            ? null
                            : (on) => setState(() {
                                _picked = on == true
                                    ? {..._picked, uid}
                                    : ({..._picked}..remove(uid));
                              }),
                        title: Text(nameOf(uid)),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Text(
                    _error!,
                    key: const Key('crews.members.error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: AppSpacing.sm,
                  children: [
                    TextButton(
                      key: const Key('crews.members.cancel'),
                      onPressed: _busy ? null : _close,
                      child: Text(strings.cancel),
                    ),
                    FilledButton(
                      key: const Key('crews.members.save'),
                      onPressed: _busy || !_dirty ? null : _save,
                      child: Text(strings.save),
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
