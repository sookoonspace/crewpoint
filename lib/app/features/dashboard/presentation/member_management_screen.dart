import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
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
import 'package:crewpoint_app/app/features/dashboard/domain/models/member.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/crews_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/roles_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/add_member_sheet.dart';

/// The event's members (Spec #186): links to roles, crews and transfer
/// for those who may open them, then everyone in one card with their roles,
/// and remove or make admin for those who may.
class MemberManagementScreen extends ConsumerStatefulWidget {
  const MemberManagementScreen({
    super.key,
    required this.event,
    required this.currentUserId,
  });

  final EventModel event;
  final String currentUserId;

  @override
  ConsumerState<MemberManagementScreen> createState() =>
      _MemberManagementScreenState();
}

class _MemberManagementScreenState
    extends ConsumerState<MemberManagementScreen> {
  final Set<String> _processingIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.roles;
    final event = widget.event;
    final currentUserId = widget.currentUserId;
    // Each person's roles come from their member document, live. An event
    // with none falls back to the old arrays.
    final members = {
      for (final m
          in ref.watch(eventMembersProvider(event.id)).value ??
              const <MemberModel>[])
        m.uid: m,
    };
    List<String> rolesOf(String uid) =>
        members[uid]?.roleIds ?? event.rolesOf(uid);
    // Custom roles show their own name, and edited presets their new one.
    final roleNames = {
      for (final role
          in ref.watch(eventRolesProvider(event.id)).value ??
              RoleCatalogue.current.presets)
        // An unedited Participant shows as the event's own word.
        role.id: role.id == 'participant' && !role.isEdited
            ? event.words.one('member')
            : role.name,
    };
    final canOpenDetail =
        event.can(currentUserId, 'members.manage') ||
        event.can(currentUserId, 'roles.manage');
    bool memberCan(String uid, String permission) =>
        members[uid]?.permissions.contains(permission) ??
        event.can(uid, permission);

    Widget link(Key key, IconData icon, String title, String route) =>
        CpListRow(
          key: key,
          leading: Icon(icon, size: cp.sizes.iconMd, color: cp.colors.accent),
          title: title,
          onTap: () => context.push('/dashboard/event/${event.id}/$route'),
        );
    final links = [
      if (canViewRoles(event, currentUserId))
        link(
          const Key('members.roles'),
          CpIcons.shield,
          strings.title,
          'roles',
        ),
      if (canViewCrews(event, currentUserId))
        link(
          const Key('members.crews'),
          CpIcons.members,
          event.words.other('crew'),
          'crews',
        ),
      if (event.isOwner(currentUserId))
        link(
          const Key('members.transfer'),
          CpIcons.actionSwap,
          context.strings.transfer.title,
          'transfer',
        ),
    ];

    final ids = event.memberIds;
    Widget row(int index) {
      final memberId = ids[index];
      final roles = rolesOf(memberId);
      final memberIsOwner = roles.contains('owner');
      final memberIsAdmin = roles.contains('admin');
      // Each row reads its own name, so only the rows on screen load
      // names (Req 43a).
      return _MemberTile(
        eventId: event.id,
        memberId: memberId,
        role: _roleLabel(roles, roleNames, event.words.one('member')),
        isOwner: memberIsOwner,
        onOpen: canOpenDetail || memberId == currentUserId
            ? () =>
                  context.push('/dashboard/event/${event.id}/members/$memberId')
            : null,
        canRemove: event.canRemoveMember(
          actor: currentUserId,
          target: memberId,
          targetCan: (p) => memberCan(memberId, p),
          targetIsOwner: memberIsOwner,
        ),
        canPromote: event.can(currentUserId, 'roles.manage') && !memberIsOwner,
        isAdmin: memberIsAdmin,
        isProcessing: _processingIds.contains(memberId),
        onRemove: () => _removeMember(memberId),
        onToggleAdmin: () => _toggleAdmin(memberId, memberIsAdmin),
      );
    }

    return AdminScaffold(
      title: strings.membersTitle(
        event.words.other('member'),
        event.memberCount,
      ),
      actions: [
        if (event.can(currentUserId, 'members.manage'))
          CpTopBarAction(
            key: const Key('members.invite'),
            icon: CpIcons.memberAdd,
            tooltip: strings.inviteTooltip(event.words.other('member')),
            primary: true,
            onPressed: () => AddMemberSheet.show(
              memberLabel: event.words.other('member'),
              context: context,
              eventId: event.id,
              canChooseRole: event.can(currentUserId, 'roles.manage'),
            ),
          ),
      ],
      body: LayoutBuilder(
        builder: (context, box) {
          // The phone column, centred on a wide screen.
          final side = math.max(
            cp.space.lg,
            (box.maxWidth - cp.sizes.phoneColumn) / 2,
          );
          final card = BoxDecoration(
            color: cp.colors.surface,
            borderRadius: cp.radii.md,
            border: Border.all(
              color: cp.colors.border,
              width: cp.sizes.hairline,
            ),
            boxShadow: cp.shadows.card,
          );
          return CustomScrollView(
            key: const Key('memberManagement.body.clamped'),
            slivers: [
              if (links.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, cp.space.sm, side, 0),
                  sliver: SliverToBoxAdapter(
                    child: CpCard(child: CpRowGroup(children: links)),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  side,
                  cp.space.lg,
                  side,
                  cp.space.xxl,
                ),
                // A lazy list in one card, so a large event builds only
                // the rows on screen.
                sliver: DecoratedSliver(
                  decoration: card,
                  sliver: SliverList.separated(
                    itemCount: ids.length,
                    itemBuilder: (_, i) => row(i),
                    separatorBuilder: (_, _) => Divider(
                      height: cp.sizes.hairline,
                      thickness: cp.sizes.hairline,
                      color: cp.colors.border,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The names of [roleIds].
  String _roleLabel(
    List<String> roleIds,
    Map<String, String> names,
    String memberWord,
  ) {
    if (roleIds.isEmpty) return memberWord;
    return roleIds.map((id) => names[id] ?? id).join(', ');
  }

  Future<void> _removeMember(String targetId) async {
    final strings = context.strings.roles;
    final member = widget.event.words.one('member');
    final confirmed = await confirmAction(
      context,
      title: strings.removeMemberTitle(member),
      body: strings.removeMemberBody,
      action: strings.remove,
      confirmKey: Key('members.tile.$targetId.removeConfirm'),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingIds.add(targetId));
    try {
      await ref
          .read(memberCallsProvider)
          .removeMember(eventId: widget.event.id, uid: targetId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.roles.memberRemoved(
                widget.event.words.one('member'),
              ),
            ),
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userMessageFor(
                e,
                stackTrace: st,
                strings: context.strings.errors,
                fallback: context.strings.roles.removeFailed,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(targetId));
    }
  }

  Future<void> _toggleAdmin(String targetId, bool currentlyAdmin) async {
    setState(() => _processingIds.add(targetId));
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        currentlyAdmin ? 'demoteAdmin' : 'promoteToAdmin',
      );
      await callable.call<Map<String, dynamic>>({
        'eventId': widget.event.id,
        'targetUserId': targetId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyAdmin
                  ? context.strings.roles.demoted
                  : context.strings.roles.promoted,
            ),
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userMessageFor(
                e,
                stackTrace: st,
                strings: context.strings.errors,
                fallback: currentlyAdmin
                    ? context.strings.roles.demoteFailed
                    : context.strings.roles.promoteFailed,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(targetId));
    }
  }
}

/// One member. It reads its own name, so only the rows on screen load
/// names (Req 43a).
class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.eventId,
    required this.memberId,
    required this.role,
    required this.isOwner,
    required this.canRemove,
    required this.canPromote,
    required this.isAdmin,
    required this.isProcessing,
    this.onRemove,
    this.onToggleAdmin,
    this.onOpen,
  });

  final String eventId;
  final String memberId;
  final String role;
  final bool isOwner;
  final bool canRemove;
  final bool canPromote;
  final bool isAdmin;
  final bool isProcessing;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleAdmin;

  /// Opens Member detail, when the viewer may see it.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.roles;
    final name = ref
        .watch(eventProfileProvider((eventId: eventId, uid: memberId)))
        .value
        ?.displayName;
    final displayName = name != null && name.isNotEmpty
        ? name
        : (memberId.length > 8 ? '${memberId.substring(0, 8)}…' : memberId);
    final Widget? menu;
    if (isProcessing) {
      menu = Padding(
        padding: EdgeInsets.all(cp.space.md),
        child: SizedBox.square(
          dimension: cp.sizes.iconLg,
          child: CircularProgressIndicator(
            strokeWidth: cp.sizes.hairline * 2,
            color: cp.colors.accent,
          ),
        ),
      );
    } else if (canRemove || canPromote) {
      menu = PopupMenuButton<String>(
        key: Key('members.tile.$memberId.menu'),
        tooltip: strings.memberOptions,
        icon: Icon(
          CpIcons.actionMore,
          size: cp.sizes.iconMd,
          color: cp.colors.textMuted,
        ),
        itemBuilder: (_) => [
          if (canPromote)
            PopupMenuItem(
              key: Key('members.tile.$memberId.admin'),
              value: 'toggle_admin',
              child: Text(isAdmin ? strings.removeAdmin : strings.makeAdmin),
            ),
          if (canRemove)
            PopupMenuItem(
              key: Key('members.tile.$memberId.remove'),
              value: 'remove',
              child: Text(
                strings.remove,
                style: cp.type.bodyLarge.copyWith(color: cp.colors.overdue),
              ),
            ),
        ],
        onSelected: (value) {
          if (value == 'remove') onRemove?.call();
          if (value == 'toggle_admin') onToggleAdmin?.call();
        },
      );
    } else {
      menu = null;
    }

    return Row(
      children: [
        Expanded(
          child: CpListRow(
            key: Key('members.tile.$memberId'),
            leading: CpAvatar(name: displayName),
            title: displayName,
            subtitle: role,
            trailing: isOwner
                ? Icon(
                    CpIcons.owner,
                    size: cp.sizes.iconMd,
                    color: cp.colors.accent,
                  )
                : (menu == null ? null : const SizedBox.shrink()),
            onTap: onOpen,
          ),
        ),
        ?menu,
      ],
    );
  }
}
