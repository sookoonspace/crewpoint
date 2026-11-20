import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/member.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';

/// Whether the viewer may open the Roles and Role editor screens: anyone who
/// manages members or roles. Only `roles.manage` may change them.
bool canViewRoles(EventModel event, String uid) =>
    event.can(uid, 'roles.manage') || event.can(uid, 'members.manage');

/// The event's roles: the presets, edited or not, then its custom roles
/// (Req 33, route `roles`).
class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.roles;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final canEdit = event.can(me, 'roles.manage');

    final Widget body;
    if (!canViewRoles(event, me)) {
      body = const NoAccessView();
    } else {
      final members =
          ref.watch(eventMembersProvider(event.id)).value ??
          const <MemberModel>[];
      body = switch (ref.watch(eventRolesProvider(event.id))) {
        AsyncValue(:final value?) => _RoleList(
          event: event,
          roles: value,
          members: members,
          canEdit: canEdit,
        ),
        AsyncValue(error: != null) => LoadFailedView(
          onRetry: () => ref.invalidate(eventRolesProvider(event.id)),
        ),
        _ => CpLoadingState.rows(
          key: const Key('roles.loading'),
          semanticLabel: strings.title,
        ),
      };
    }

    return AdminScaffold(
      title: strings.title,
      actions: [
        if (canEdit)
          CpTopBarAction(
            key: const Key('roles.new'),
            icon: CpIcons.actionAdd,
            tooltip: strings.newRole,
            primary: true,
            onPressed: () =>
                context.push('/dashboard/event/${event.id}/roles/new'),
          ),
      ],
      body: body,
    );
  }
}

class _RoleList extends StatelessWidget {
  const _RoleList({
    required this.event,
    required this.roles,
    required this.members,
    required this.canEdit,
  });

  final EventModel event;
  final List<RoleDefinition> roles;
  final List<MemberModel> members;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.roles;
    final presets = roles.where((r) => r.isPreset).toList();
    final custom = roles.where((r) => !r.isPreset).toList();

    return AdminList(
      listKey: const Key('roles.body'),
      children: [
        if (!canEdit)
          AdminNote(
            strings.readOnly,
            key: const Key('roles.readOnly'),
            icon: CpIcons.lock,
          ),
        CpSectionHeader(title: strings.presetsHeading),
        CpCard(
          child: CpRowGroup(
            children: [for (final role in presets) _tile(context, role)],
          ),
        ),
        CpSectionHeader(title: strings.customHeading),
        CpCard(
          child: custom.isEmpty
              ? CpListRow(
                  key: const Key('roles.empty'),
                  title: strings.noCustomRoles,
                  subtitle: strings.noCustomRolesHint,
                  leading: Icon(
                    CpIcons.statusInfo,
                    size: cp.sizes.iconMd,
                    color: cp.colors.textMuted,
                  ),
                )
              : CpRowGroup(
                  children: [for (final role in custom) _tile(context, role)],
                ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, RoleDefinition role) {
    final strings = context.strings.roles;
    final holders = members.where((m) => m.roleIds.contains(role.id)).length;
    final name = role.id == 'participant' && !role.isEdited
        ? event.words.one('member')
        : role.name;
    return CpListRow(
      key: Key('roles.tile.${role.id}'),
      title: name,
      subtitle: [
        strings.permissionCount(role.permissions.length),
        if (holders > 0) event.words.count('member', holders),
        if (role.isEdited) strings.edited,
      ].join(' · '),
      onTap: () =>
          context.push('/dashboard/event/${event.id}/roles/${role.id}'),
    );
  }
}
