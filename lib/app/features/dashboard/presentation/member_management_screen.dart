import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/member.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/crews_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/roles_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/add_member_sheet.dart';
import 'package:go_router/go_router.dart';

/// Member management screen — shows members with roles, remove/promote actions.
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

    final asyncUsers = ref.watch(usersByIdProvider(event.id));
    // displayName when set, email as second fallback. Empty string
    // signals "no resolved label" so downstream renders "Unknown
    // member" or similar.
    final displayNames = asyncUsers.maybeWhen(
      data: (users) => {
        for (final entry in users.entries)
          entry.key: () {
            final name = entry.value.displayName;
            if (name != null && name.isNotEmpty) return name;
            if (entry.value.email.isNotEmpty) return entry.value.email;
            return '';
          }(),
      },
      orElse: () => const <String, String>{},
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Members (${event.memberIds.length})'),
        elevation: 0,
        actions: [
          if (event.isOwner(currentUserId))
            IconButton(
              key: const Key('members.transfer'),
              tooltip: context.strings.transfer.title,
              onPressed: () =>
                  context.push('/dashboard/event/${event.id}/transfer'),
              icon: const Icon(AppIcons.actionSwap),
            ),
          if (canViewCrews(event, currentUserId))
            IconButton(
              key: const Key('members.crews'),
              tooltip: event.words.other('crew'),
              onPressed: () =>
                  context.push('/dashboard/event/${event.id}/crews'),
              icon: const Icon(AppIcons.members),
            ),
          if (canViewRoles(event, currentUserId))
            TextButton.icon(
              key: const Key('members.roles'),
              onPressed: () =>
                  context.push('/dashboard/event/${event.id}/roles'),
              icon: const Icon(AppIcons.shield),
              label: Text(context.strings.roles.title),
            ),
        ],
      ),
      body: ContentMaxWidth(
        key: const Key('memberManagement.body.clamped'),
        maxWidth: 720,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: Breakpoints.screenHorizontalPadding(context),
            vertical: AppSpacing.xl,
          ),
          itemCount: event.memberIds.length,
          itemBuilder: (context, index) {
            final memberId = event.memberIds[index];
            final roles = rolesOf(memberId);
            final memberIsOwner = roles.contains('owner');
            final memberIsAdmin = roles.contains('admin');
            final canRemove = event.canRemoveMember(
              actor: currentUserId,
              target: memberId,
              targetCan: (p) => memberCan(memberId, p),
              targetIsOwner: memberIsOwner,
            );
            final isProcessing = _processingIds.contains(memberId);

            return _MemberTile(
              memberId: memberId,
              displayName: displayNames[memberId],
              role: _roleLabel(roles, roleNames, event.words.one('member')),
              onOpen: canOpenDetail || memberId == currentUserId
                  ? () => context.push(
                      '/dashboard/event/${event.id}/members/$memberId',
                    )
                  : null,
              roleColor: memberIsOwner
                  ? AppColors.sage
                  : memberIsAdmin
                  ? AppColors.info
                  : AppColors.mediumGrey,
              canRemove: canRemove,
              canPromote:
                  event.can(currentUserId, 'roles.manage') && !memberIsOwner,
              isAdmin: memberIsAdmin,
              isProcessing: isProcessing,
              onRemove: () => _removeMember(memberId),
              onToggleAdmin: () => _toggleAdmin(memberId, memberIsAdmin),
            );
          },
        ),
      ),
      floatingActionButton: event.can(currentUserId, 'members.manage')
          ? FloatingActionButton(
              key: const Key('members.invite'),
              onPressed: () => AddMemberSheet.show(
                memberLabel: event.words.other('member'),
                context: context,
                eventId: event.id,
                canChooseRole: event.can(currentUserId, 'roles.manage'),
              ),
              backgroundColor: AppColors.sage,
              foregroundColor: AppColors.white,
              child: const Icon(AppIcons.memberAdd),
            )
          : null,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${widget.event.words.one('member')}?'),
        content: const Text(
          'They will lose access to this event. '
          'Their past messages and expenses will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.terracotta),
            ),
          ),
        ],
      ),
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
            content: Text('${widget.event.words.one('member')} removed'),
            backgroundColor: AppColors.sage,
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
                fallback: 'Failed to remove member',
              ),
            ),
            backgroundColor: AppColors.terracotta,
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
              currentlyAdmin ? 'Demoted to member' : 'Promoted to admin',
            ),
            backgroundColor: AppColors.sage,
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
                    ? 'Failed to demote admin'
                    : 'Failed to promote',
              ),
            ),
            backgroundColor: AppColors.terracotta,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(targetId));
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.memberId,
    required this.role,
    required this.roleColor,
    required this.canRemove,
    required this.canPromote,
    required this.isAdmin,
    required this.isProcessing,
    this.displayName,
    this.onRemove,
    this.onToggleAdmin,
    this.onOpen,
  });

  final String memberId;
  final String? displayName;
  final String role;
  final Color roleColor;
  final bool canRemove;
  final bool canPromote;
  final bool isAdmin;
  final bool isProcessing;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleAdmin;

  /// Opens Member detail, when the viewer may see it.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final Widget? trailing;
    if (isProcessing) {
      trailing = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (canRemove || canPromote) {
      trailing = PopupMenuButton<String>(
        itemBuilder: (_) => [
          if (canPromote)
            PopupMenuItem(
              value: 'toggle_admin',
              child: Text(isAdmin ? 'Remove Admin' : 'Make Admin'),
            ),
          if (canRemove)
            const PopupMenuItem(
              value: 'remove',
              child: Text(
                'Remove',
                style: TextStyle(color: AppColors.terracotta),
              ),
            ),
        ],
        onSelected: (value) {
          if (value == 'remove') onRemove?.call();
          if (value == 'toggle_admin') onToggleAdmin?.call();
        },
      );
    } else {
      trailing = null;
    }

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderLg,
        side: BorderSide(
          color: AppColors.lightGrey.withValues(alpha: 0.7),
          width: 0.5,
        ),
      ),
      child: ListTile(
        key: Key('members.tile.$memberId'),
        onTap: onOpen,
        minTileHeight: 56,
        leading: CircleAvatar(
          backgroundColor: AppColors.sageLight.withValues(alpha: 0.3),
          child: const Icon(AppIcons.navProfileFilled, color: AppColors.sage),
        ),
        title: Text(
          displayName != null && displayName!.isNotEmpty
              ? displayName!
              : (memberId.length > 8
                    ? '${memberId.substring(0, 8)}…'
                    : memberId),
        ),
        subtitle: Text(
          role,
          style: TextStyle(
            color: roleColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        trailing: trailing,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      ),
    );
  }
}
