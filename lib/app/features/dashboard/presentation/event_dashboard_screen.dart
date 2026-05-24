import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_sizes.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/loading_animation.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/add_member_sheet.dart';

/// Event detail hub — shows event info, member avatars, and quick links
/// to sub-features (Chat, Budget, Tasks).
class EventDashboardScreen extends StatelessWidget {
  const EventDashboardScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero
          SliverToBoxAdapter(child: _EventHero(event: event)),

          // Content
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: Breakpoints.screenHorizontalPadding(context),
              vertical: AppSpacing.xl,
            ),
            sliver: SliverConstrainedCrossAxis(
              maxExtent: 960,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(
                    key: Key('eventDashboard.body.clamped'),
                    height: 1,
                  ),
                  if (event.description != null &&
                      event.description!.isNotEmpty) ...[
                    Text(
                      event.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // Member avatars row
                  _MembersPreview(
                    memberCount: event.memberIds.length,
                    onTap: () =>
                        context.push('/dashboard/event/${event.id}/members'),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Invite Members tile — admin/owner only. Explicit
                  // null-uid guard so we don't rely on isAdmin('') semantics.
                  Consumer(
                    builder: (_, ref, _) {
                      final uid = ref.watch(currentUserIdProvider);
                      if (uid == null || !event.isAdmin(uid)) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: _QuickLinkCard(
                          key: const Key('eventDashboard.inviteMembers.tile'),
                          icon: AppIcons.memberAdd,
                          label: 'Invite Members',
                          subtitle: 'Share a code to add people',
                          color: AppColors.terracotta,
                          onTap: () => AddMemberSheet.show(
                            context: context,
                            eventId: event.id,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Quick-link cards. No `extra:` payload — child routes
                  // resolve the event by id via EventGuard.
                  _QuickLinkCard(
                    icon: AppIcons.navChatFilled,
                    label: 'Chat',
                    subtitle: 'Messages & alerts',
                    color: AppColors.sage,
                    onTap: () =>
                        context.push('/dashboard/event/${event.id}/chat'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _QuickLinkCard(
                    icon: AppIcons.navBudgetFilled,
                    label: 'Budget',
                    subtitle: 'Expenses & settlements',
                    color: AppColors.terracotta,
                    onTap: () =>
                        context.push('/dashboard/event/${event.id}/budget'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _QuickLinkCard(
                    icon: AppIcons.statusDone,
                    label: 'Tasks',
                    subtitle: 'To-dos & assignments',
                    color: Theme.of(context).colorScheme.onSurface,
                    onTap: () =>
                        context.push('/dashboard/event/${event.id}/tasks'),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Event actions (archive, leave, delete) — uid threaded
                  // from currentUserIdProvider so isOwner / isAdmin /
                  // isMember branches evaluate correctly.
                  Consumer(
                    builder: (_, ref, _) => _EventActions(
                      event: event,
                      currentUserId: ref.watch(currentUserIdProvider) ?? '',
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventHero extends StatelessWidget {
  const _EventHero({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: .topCenter,
          end: .bottomCenter,
          colors: [AppColors.charcoal, AppColors.charcoalDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              // Back button + settings
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      AppIcons.actionBack,
                      color: AppColors.offWhite,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  Consumer(
                    builder: (_, ref, _) {
                      final uid = ref.watch(currentUserIdProvider);
                      if (uid == null || !event.isAdmin(uid)) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        key: const Key('event.dashboard.settingsIcon'),
                        icon: const Icon(
                          AppIcons.actionSettings,
                          color: AppColors.offWhite,
                        ),
                        onPressed: () =>
                            context.push('/dashboard/event/${event.id}/edit'),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Event type badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  event.eventType.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.sageLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Title
              Text(
                event.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.offWhite,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Dates
              if (event.startDate != null)
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    const Icon(
                      AppIcons.calendar,
                      size: AppSizes.iconXs,
                      color: AppColors.sageLight,
                    ),
                    Text(
                      dateFormat.format(event.startDate!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.sageLight,
                      ),
                    ),
                    if (event.endDate != null) ...[
                      const Text(
                        '—',
                        style: TextStyle(color: AppColors.sageLight),
                      ),
                      Text(
                        dateFormat.format(event.endDate!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.sageLight,
                        ),
                      ),
                    ],
                  ],
                ),

              // Status badge for archived
              if (event.status == EventStatus.archived) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.terracotta.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Archived',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.terracottaLight,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersPreview extends StatelessWidget {
  const _MembersPreview({required this.memberCount, this.onTap});

  final int memberCount;
  final VoidCallback? onTap;

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
        leading: const Icon(AppIcons.members, color: AppColors.sage),
        title: Text('$memberCount member${memberCount != 1 ? 's' : ''}'),
        trailing: Icon(
          AppIcons.chevronRight,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  const _QuickLinkCard({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

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
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(label),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: Icon(
          AppIcons.chevronRight,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      ),
    );
  }
}

/// Archive, Leave, Delete actions for the event dashboard.
class _EventActions extends StatefulWidget {
  const _EventActions({required this.event, required this.currentUserId});

  final EventModel event;
  final String currentUserId;

  @override
  State<_EventActions> createState() => _EventActionsState();
}

class _EventActionsState extends State<_EventActions> {
  bool _isLoading = false;

  Future<void> _leaveEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Event?'),
        content: const Text(
          'You will lose access to this event. '
          'Your past messages and expenses will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Leave',
              style: TextStyle(color: AppColors.terracotta),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'removeEventMember',
      );
      await callable.call<Map<String, dynamic>>({
        'eventId': widget.event.id,
        'targetUserId': widget.currentUserId,
      });
      if (mounted) context.go('/dashboard');
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to leave event'),
            backgroundColor: AppColors.terracotta,
          ),
        );
      }
    }
  }

  Future<void> _deleteEvent() async {
    // Step 1: Warning
    final step1 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Event?',
          style: TextStyle(color: AppColors.terracotta),
        ),
        content: const Text(
          'This will permanently delete the event and all its data: '
          'messages, expenses, tasks, and invite codes.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Continue',
              style: TextStyle(color: AppColors.terracotta),
            ),
          ),
        ],
      ),
    );

    if (step1 != true || !mounted) return;

    // Step 2: Final confirmation
    final step2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Are you sure?',
          style: TextStyle(color: AppColors.terracotta),
        ),
        content: const Text(
          'All event data will be permanently erased for all members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (step2 != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteEvent');
      await callable.call<Map<String, dynamic>>({'eventId': widget.event.id});
      if (mounted) context.go('/dashboard');
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete event'),
            backgroundColor: AppColors.terracotta,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(child: LoadingAnimation()),
      );
    }

    final isOwner = widget.event.isOwner(widget.currentUserId);
    final isAdmin = widget.event.isAdmin(widget.currentUserId);

    return Column(
      crossAxisAlignment: .start,
      spacing: AppSpacing.md,
      children: [
        // Archive toggle (admin/owner)
        if (isAdmin || isOwner)
          Card(
            elevation: 0,
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderLg,
              side: BorderSide(
                color: AppColors.lightGrey.withValues(alpha: 0.7),
                width: 0.5,
              ),
            ),
            child: Consumer(
              builder: (_, ref, _) => SwitchListTile(
                title: const Text('Archive Event'),
                subtitle: Text(
                  widget.event.status == EventStatus.archived
                      ? 'Event is archived (read-only)'
                      : 'Archive to make read-only',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: widget.event.status == EventStatus.archived,
                onChanged: (archived) async {
                  final updated = widget.event.copyWith(
                    status: archived
                        ? EventStatus.archived
                        : EventStatus.active,
                  );
                  final ok = await ref
                      .read(eventRepositoryProvider)
                      .updateEvent(updated);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not update archive status'),
                        backgroundColor: AppColors.terracotta,
                      ),
                    );
                  }
                },
                activeThumbColor: AppColors.sage,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.borderLg,
                ),
              ),
            ),
          ),

        // Leave event (non-owner members)
        if (!isOwner)
          Card(
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
              leading: Icon(
                AppIcons.actionLogout,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              title: const Text('Leave Event'),
              trailing: Icon(
                AppIcons.chevronRight,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onTap: _leaveEvent,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.borderLg,
              ),
            ),
          ),

        // Delete event (owner only) — danger zone
        if (isOwner) ...[
          const SizedBox(height: AppSpacing.lg),
          Card(
            elevation: 0,
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderLg,
              side: BorderSide(
                color: AppColors.terracotta.withValues(alpha: 0.3),
              ),
            ),
            child: ListTile(
              leading: const Icon(
                AppIcons.actionDeletePermanent,
                color: AppColors.terracotta,
              ),
              title: const Text(
                'Delete Event',
                style: TextStyle(color: AppColors.terracotta),
              ),
              trailing: const Icon(
                AppIcons.chevronRight,
                color: AppColors.terracottaLight,
              ),
              onTap: _deleteEvent,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.borderLg,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
