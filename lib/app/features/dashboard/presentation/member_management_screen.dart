import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/add_member_sheet.dart';

/// Member management screen — shows members with roles, remove/promote actions.
class MemberManagementScreen extends StatelessWidget {
  const MemberManagementScreen({
    super.key,
    required this.event,
    required this.currentUserId,
  });

  final EventModel event;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final isOwner = event.isOwner(currentUserId);
    final isAdmin = event.isAdmin(currentUserId);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Members (${event.memberIds.length})'),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: event.memberIds.length,
        itemBuilder: (context, index) {
          final memberId = event.memberIds[index];
          final memberIsOwner = event.isOwner(memberId);
          final memberIsAdmin = event.isAdmin(memberId);
          final canRemove =
              (isOwner || isAdmin) &&
              !memberIsOwner &&
              memberId != currentUserId;

          return _MemberTile(
            memberId: memberId,
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
            onRemove: () => _removeMember(context, memberId),
            onToggleAdmin: () => _toggleAdmin(context, memberId, memberIsAdmin),
          );
        },
      ),
      floatingActionButton: (isOwner || isAdmin)
          ? FloatingActionButton(
              onPressed: () =>
                  AddMemberSheet.show(context: context, eventId: event.id),
              backgroundColor: AppColors.sage,
              foregroundColor: AppColors.white,
              child: const Icon(Icons.person_add_rounded),
            )
          : null,
    );
  }

  Future<void> _removeMember(BuildContext context, String targetId) async {
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

    if (confirmed != true || !context.mounted) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'removeEventMember',
      );
      await callable.call<Map<String, dynamic>>({
        'eventId': event.id,
        'targetUserId': targetId,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member removed'),
            backgroundColor: AppColors.sage,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove member'),
            backgroundColor: AppColors.terracotta,
          ),
        );
      }
    }
  }

  Future<void> _toggleAdmin(
    BuildContext context,
    String targetId,
    bool currentlyAdmin,
  ) async {
    // TODO: Implement promote/demote via Cloud Function
    // For V1, this is a placeholder — promote/demote will need
    // a new CF or direct Firestore write by owner
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyAdmin ? 'Demoted to member' : 'Promoted to admin',
          ),
          backgroundColor: AppColors.sage,
        ),
      );
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
    this.onRemove,
    this.onToggleAdmin,
  });

  final String memberId;
  final String role;
  final Color roleColor;
  final bool canRemove;
  final bool canPromote;
  final bool isAdmin;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleAdmin;

  @override
  Widget build(BuildContext context) {
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
          child: const Icon(Icons.person, color: AppColors.sage),
        ),
        title: Text(
          memberId.length > 8 ? '${memberId.substring(0, 8)}...' : memberId,
        ),
        subtitle: Text(
          role,
          style: TextStyle(
            color: roleColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        trailing: (canRemove || canPromote)
            ? PopupMenuButton<String>(
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
              )
            : null,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      ),
    );
  }
}
