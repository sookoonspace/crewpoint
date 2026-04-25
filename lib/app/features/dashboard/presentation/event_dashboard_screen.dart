import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Event detail hub — shows event info, member avatars, and quick links
/// to sub-features (Chat, Budget, Tasks).
class EventDashboardScreen extends StatelessWidget {
  const EventDashboardScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          // Hero
          SliverToBoxAdapter(child: _EventHero(event: event)),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (event.description != null &&
                    event.description!.isNotEmpty) ...[
                  Text(
                    event.description!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.darkGrey),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // Member avatars row
                _MembersPreview(
                  memberCount: event.memberIds.length,
                  onTap: () =>
                      context.push('/dashboard/event/${event.id}/members'),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Quick-link cards
                _QuickLinkCard(
                  icon: Icons.chat_rounded,
                  label: 'Chat',
                  subtitle: 'Messages & alerts',
                  color: AppColors.sage,
                  onTap: () {
                    // Navigate to event chat
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _QuickLinkCard(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Budget',
                  subtitle: 'Expenses & settlements',
                  color: AppColors.terracotta,
                  onTap: () {
                    // Navigate to event budget
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _QuickLinkCard(
                  icon: Icons.task_alt_rounded,
                  label: 'Tasks',
                  subtitle: 'To-dos & assignments',
                  color: AppColors.charcoal,
                  onTap: () {
                    // Navigate to event tasks
                  },
                ),

                const SizedBox(height: AppSpacing.xl),
              ]),
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
                      Icons.arrow_back,
                      color: AppColors.offWhite,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  if (event.isAdmin(event.creatorId))
                    IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: AppColors.offWhite,
                      ),
                      onPressed: () {
                        // Event settings
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
                      Icons.calendar_today,
                      size: 14,
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
        leading: const Icon(Icons.group_outlined, color: AppColors.sage),
        title: Text('$memberCount member${memberCount != 1 ? 's' : ''}'),
        trailing: const Icon(Icons.chevron_right, color: AppColors.mediumGrey),
        onTap: onTap,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  const _QuickLinkCard({
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
        subtitle: Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGrey),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.mediumGrey),
        onTap: onTap,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      ),
    );
  }
}
