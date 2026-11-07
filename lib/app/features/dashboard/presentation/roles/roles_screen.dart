import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
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
      body = ref
          .watch(eventRolesProvider(event.id))
          .when(
            loading: () => const Center(
              child: CircularProgressIndicator(key: Key('roles.loading')),
            ),
            error: (_, _) => LoadFailedView(
              onRetry: () => ref.invalidate(eventRolesProvider(event.id)),
            ),
            data: (roles) => _RoleList(
              event: event,
              roles: roles,
              members: members,
              canEdit: canEdit,
            ),
          );
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.title), elevation: 0),
      body: body,
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              key: const Key('roles.new'),
              onPressed: () =>
                  context.push('/dashboard/event/${event.id}/roles/new'),
              icon: const Icon(AppIcons.actionAdd),
              label: Text(strings.newRole),
            )
          : null,
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
    final strings = context.strings.roles;
    final theme = Theme.of(context);
    final presets = roles.where((r) => r.isPreset).toList();
    final custom = roles.where((r) => !r.isPreset).toList();

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return ContentMaxWidth(
      key: const Key('roles.body'),
      maxWidth: 720,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Breakpoints.screenHorizontalPadding(context),
          AppSpacing.md,
          Breakpoints.screenHorizontalPadding(context),
          // Room for the button over the last tile.
          AppSpacing.xxl * 3,
        ),
        children: [
          if (!canEdit)
            Text(
              strings.readOnly,
              key: const Key('roles.readOnly'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          heading(strings.presetsHeading),
          for (final role in presets) _tile(context, role),
          heading(strings.customHeading),
          if (custom.isEmpty)
            ListTile(
              key: const Key('roles.empty'),
              contentPadding: EdgeInsets.zero,
              title: Text(strings.noCustomRoles),
              subtitle: Text(strings.noCustomRolesHint),
            )
          else
            for (final role in custom) _tile(context, role),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, RoleDefinition role) {
    final strings = context.strings.roles;
    final holders = members.where((m) => m.roleIds.contains(role.id)).length;
    final name = role.id == 'participant' && !role.isEdited
        ? event.words.one('member')
        : role.name;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        key: Key('roles.tile.${role.id}'),
        minTileHeight: 56,
        title: Text(name),
        subtitle: Text(
          [
            strings.permissionCount(role.permissions.length),
            if (holders > 0) event.words.count('member', holders),
            if (role.isEdited) strings.edited,
          ].join(' · '),
        ),
        trailing: const Icon(AppIcons.chevronRight),
        onTap: () =>
            context.push('/dashboard/event/${event.id}/roles/${role.id}'),
      ),
    );
  }
}
