import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/add_member_sheet.dart';

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
    final isOwner = event.isOwner(currentUserId);
    final isAdmin = event.isAdmin(currentUserId);

    final asyncUsers = ref.watch(usersByIdProvider(event.memberIds));
    final displayNames = asyncUsers.maybeWhen(
      data: (users) => {
        for (final entry in users.entries)
          entry.key: entry.value.displayName ?? '',
      },
      orElse: () => const <String, String>{},
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Members (${event.memberIds.length})'),
        elevation: 0,
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
            final memberIsOwner = event.isOwner(memberId);
            final memberIsAdmin = event.isAdmin(memberId);
            final canRemove =
                (isOwner || isAdmin) &&
                !memberIsOwner &&
                memberId != currentUserId;
            final isProcessing = _processingIds.contains(memberId);

            return _MemberTile(
              memberId: memberId,
              displayName: displayNames[memberId],
              role: memberIsOwner
                  ? 'Owner'
                  : memberIsAdmin
                  ? 'Admin'
                  : 'Member',
              roleColor: memberIsOwner
                  ? AppColors.sage
                  : memberIsAdmin
                  ? AppColors.info
                  : AppColors.mediumGrey,
              canRemove: canRemove,
              canPromote: isOwner && !memberIsOwner,
              isAdmin: memberIsAdmin,
              isProcessing: isProcessing,
              onRemove: () => _removeMember(memberId),
              onToggleAdmin: () => _toggleAdmin(memberId, memberIsAdmin),
            );
          },
        ),
      ),
      floatingActionButton: (isOwner || isAdmin)
          ? FloatingActionButton(
              onPressed: () =>
                  AddMemberSheet.show(context: context, eventId: event.id),
              backgroundColor: AppColors.sage,
              foregroundColor: AppColors.white,
              child: const Icon(AppIcons.memberAdd),
            )
          : null,
    );
  }

  Future<void> _removeMember(String targetId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member?'),
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
      final callable = FirebaseFunctions.instance.httpsCallable(
        'removeEventMember',
      );
      await callable.call<Map<String, dynamic>>({
        'eventId': widget.event.id,
        'targetUserId': targetId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member removed'),
            backgroundColor: AppColors.sage,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove member'),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyAdmin ? 'Failed to demote admin' : 'Failed to promote',
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
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderLg,
        side: BorderSide(
          color: AppColors.lightGrey.withValues(alpha: 0.7),
          width: 0.5,
        ),
      ),
      child: ListTile(
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
