import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';

/// One person in an event: their roles, what those let them do, and removal
/// (Req 33, route `members/:uid`). Anyone can see their own; seeing others
/// needs `members.manage` or `roles.manage`, and changing roles needs
/// `roles.manage`.
class MemberDetailScreen extends ConsumerStatefulWidget {
  const MemberDetailScreen({super.key, required this.event, required this.uid});

  final EventModel event;
  final String uid;

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  /// The roles picked here, or null before anything is changed, which shows
  /// the saved roles live.
  List<String>? _picked;
  bool _busy = false;

  Future<void> _saveRoles(List<String> roleIds) async {
    final strings = context.strings.roles;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(memberCallsProvider)
          .setMemberRoles(
            eventId: widget.event.id,
            uid: widget.uid,
            roleIds: roleIds,
          );
      if (!mounted) return;
      setState(() => _picked = null);
      messenger.showSnackBar(SnackBar(content: Text(strings.rolesSaved)));
    } catch (e, st) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userMessageFor(
              e,
              stackTrace: st,
              strings: context.strings.errors,
              fallback: strings.rolesSaveFailed,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String name) async {
    final strings = context.strings.roles;
    final confirmed = await confirmAction(
      context,
      title: strings.removeTitle(name),
      body: strings.removeBody,
      action: strings.remove,
      confirmKey: const Key('members.detail.removeConfirm'),
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(memberCallsProvider)
          .removeMember(eventId: widget.event.id, uid: widget.uid);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(strings.removed(name))));
      setState(() => _picked = null);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard/event/${widget.event.id}/members');
      }
    } catch (e, st) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userMessageFor(
              e,
              stackTrace: st,
              strings: context.strings.errors,
              fallback: strings.removeFailed,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.roles;
    final event = widget.event;
    final uid = widget.uid;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final memberWord = event.words.one('member');
    final canManage =
        event.can(me, 'members.manage') || event.can(me, 'roles.manage');

    final user = ref
        .watch(eventProfileProvider((eventId: event.id, uid: uid)))
        .value;
    final name = uid == me
        ? strings.you
        : (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email.isNotEmpty ?? false)
        ? user!.email
        : memberWord;

    final dirty = _picked != null;
    Widget scaffold(Widget body) => PopScope(
      canPop: !dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context) && mounted) {
          setState(() => _picked = null);
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(name), elevation: 0),
        body: body,
      ),
    );

    if (!canManage && uid != me) return scaffold(const NoAccessView());

    final members = ref.watch(eventMembersProvider(event.id));
    final roles = ref.watch(eventRolesProvider(event.id));
    if ((members.hasError && !members.hasValue) ||
        (roles.hasError && !roles.hasValue)) {
      return scaffold(
        LoadFailedView(
          onRetry: () {
            ref.invalidate(eventMembersProvider(event.id));
            ref.invalidate(eventRolesProvider(event.id));
          },
        ),
      );
    }
    if (!members.hasValue || !roles.hasValue) {
      return scaffold(
        const Center(
          child: CircularProgressIndicator(key: Key('roles.loading')),
        ),
      );
    }

    final member = members.value!.where((m) => m.uid == uid).firstOrNull;
    // An event with no member documents still lists people from the arrays.
    final inEvent = member != null || event.memberIds.contains(uid);
    if (!inEvent) {
      return scaffold(GoneView(message: strings.memberGone(memberWord)));
    }

    final allRoles = roles.value!;
    final saved = member?.roleIds ?? event.rolesOf(uid);
    final current = _picked ?? saved;
    final isOwner = saved.contains('owner');
    final canEditRoles = event.can(me, 'roles.manage') && !_busy;
    final grants = computePermissions(current, allRoles);
    final crews = ref.watch(eventCrewsProvider(event.id)).value ?? const [];
    final crewNames = [
      for (final crew in crews)
        if (member?.crewIds.contains(crew.id) ?? false) crew.name,
    ];
    final canRemove = event.canRemoveMember(
      actor: me,
      target: uid,
      targetCan: (p) => member?.permissions.contains(p) ?? event.can(uid, p),
      targetIsOwner: isOwner,
    );

    String roleName(RoleDefinition role) =>
        role.id == 'participant' && !role.isEdited ? memberWord : role.name;

    final theme = Theme.of(context);
    return scaffold(
      ContentMaxWidth(
        key: const Key('members.detail.body'),
        maxWidth: 720,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: Breakpoints.screenHorizontalPadding(context),
            vertical: AppSpacing.lg,
          ),
          children: [
            Text(strings.rolesHeading, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final role in allRoles)
                  if (canEditRoles && !role.isOwner)
                    FilterChip(
                      key: Key('members.detail.role.${role.id}'),
                      label: Text(roleName(role)),
                      selected: current.contains(role.id),
                      onSelected: (on) => setState(() {
                        final next = [
                          for (final r in current)
                            if (r != role.id) r,
                          if (on) role.id,
                        ];
                        _picked = _sameRoles(next, saved) ? null : next;
                      }),
                    )
                  else if (current.contains(role.id))
                    Chip(
                      key: Key('members.detail.role.${role.id}'),
                      label: Text(roleName(role)),
                    ),
              ],
            ),
            if (isOwner)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  strings.ownerNote,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (dirty) ...[
              const SizedBox(height: AppSpacing.md),
              if (current.isEmpty)
                Text(
                  strings.pickOneRole,
                  key: const Key('members.detail.pickOne'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              FilledButton(
                key: const Key('members.detail.save'),
                onPressed: current.isEmpty || _busy
                    ? null
                    : () => _saveRoles(current),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(strings.saveRoles),
              ),
            ],
            if (crewNames.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                event.words.other('crew'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final name in crewNames)
                    Chip(
                      key: Key('members.detail.crew.$name'),
                      label: Text(name),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text(strings.grantsHeading, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (grants.isEmpty)
              Text(
                strings.grantsNothing,
                key: const Key('members.detail.grantsNothing'),
              )
            else
              for (final p in grants)
                Padding(
                  key: Key('members.detail.grant.$p'),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text('• ${strings.permission(p)}'),
                ),
            if (canRemove) ...[
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton(
                key: const Key('members.detail.remove'),
                onPressed: _busy ? null : () => _remove(name),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(strings.remove),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static bool _sameRoles(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);
}
