import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
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
    Widget scaffold(Widget body, {Widget? bottom}) => PopScope(
      canPop: !dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context) && mounted) {
          setState(() => _picked = null);
          navigator.pop();
        }
      },
      child: AdminScaffold(title: name, body: body, bottom: bottom),
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
        CpLoadingState.rows(
          key: const Key('roles.loading'),
          semanticLabel: name,
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

    final cp = context.cp;
    final heldRoles = [
      for (final role in allRoles)
        if (current.contains(role.id)) role,
    ];
    return scaffold(
      bottom: dirty
          ? AdminSaveBar(
              child: CpButton(
                key: const Key('members.detail.save'),
                label: strings.saveRoles,
                busy: _busy,
                onPressed: current.isEmpty || _busy
                    ? null
                    : () => _saveRoles(current),
              ),
            )
          : null,
      AdminList(
        listKey: const Key('members.detail.body'),
        children: [
          CpCard(
            child: CpListRow(
              leading: CpAvatar(name: name),
              title: name,
              subtitle: heldRoles.map(roleName).join(', '),
            ),
          ),
          if (canEditRoles)
            CpChoiceChips<String>(
              label: strings.rolesHeading,
              multiple: true,
              choices: [
                for (final role in allRoles)
                  if (!role.isOwner)
                    CpChoice(
                      role.id,
                      roleName(role),
                      key: Key('members.detail.role.${role.id}'),
                    ),
              ],
              selected: current.toSet(),
              onChanged: (picked) => setState(() {
                // Keep the saved order, then add new picks in catalogue order.
                final next = [
                  for (final r in current)
                    if (picked.contains(r)) r,
                  for (final role in allRoles)
                    if (picked.contains(role.id) && !current.contains(role.id))
                      role.id,
                ];
                _picked = _sameRoles(next, saved) ? null : next;
              }),
            )
          else ...[
            CpSectionHeader(title: strings.rolesHeading),
            Wrap(
              spacing: cp.space.sm,
              runSpacing: cp.space.sm,
              children: [
                for (final role in heldRoles)
                  CpTag(
                    key: Key('members.detail.role.${role.id}'),
                    label: roleName(role),
                  ),
              ],
            ),
          ],
          if (dirty && current.isEmpty)
            KeyedSubtree(
              key: const Key('members.detail.pickOne'),
              child: CpFieldError(strings.pickOneRole),
            ),
          if (isOwner) AdminNote(strings.ownerNote, icon: CpIcons.statusInfo),
          if (crewNames.isNotEmpty) ...[
            CpSectionHeader(title: event.words.other('crew')),
            Wrap(
              spacing: cp.space.sm,
              runSpacing: cp.space.sm,
              children: [
                for (final name in crewNames)
                  CpTag(
                    key: Key('members.detail.crew.$name'),
                    label: name,
                    tone: CpTagTone.quiet,
                  ),
              ],
            ),
          ],
          CpSectionHeader(title: strings.grantsHeading),
          CpCard(
            child: grants.isEmpty
                ? CpListRow(
                    key: const Key('members.detail.grantsNothing'),
                    title: strings.grantsNothing,
                  )
                : CpRowGroup(
                    children: [
                      for (final p in grants)
                        CpListRow(
                          key: Key('members.detail.grant.$p'),
                          leading: Icon(
                            CpIcons.check,
                            size: cp.sizes.iconMd,
                            color: cp.colors.accent,
                          ),
                          title: strings.permission(p),
                        ),
                    ],
                  ),
          ),
          if (canRemove)
            CpButton.destructive(
              key: const Key('members.detail.remove'),
              label: strings.remove,
              icon: CpIcons.actionDelete,
              expand: true,
              onPressed: _busy ? null : () => _remove(name),
            ),
        ],
      ),
    );
  }

  static bool _sameRoles(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);
}
