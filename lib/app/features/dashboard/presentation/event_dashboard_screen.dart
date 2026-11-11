import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_sizes.dart';
import 'package:crewpoint_app/app/core/format/event_date_range.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/loading_animation.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/member.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_status_label.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/add_member_sheet.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/mute_event_sheet.dart';

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

                  // Shown to the person offered ownership (Req 30).
                  Consumer(
                    builder: (_, ref, _) {
                      final uid = ref.watch(currentUserIdProvider);
                      final offer = ref
                          .watch(ownershipOfferProvider(event.id))
                          .value;
                      if (uid == null || offer == null || offer.to != uid) {
                        return const SizedBox.shrink();
                      }
                      final strings = context.strings.transfer;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Card(
                          key: const Key('event.ownershipOffer'),
                          elevation: 0,
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          child: ListTile(
                            minTileHeight: 56,
                            leading: const Icon(AppIcons.actionSwap),
                            title: Text(strings.title),
                            subtitle: Text(strings.bannerBody),
                            trailing: TextButton(
                              key: const Key('event.ownershipOffer.open'),
                              onPressed: () => context.push(
                                '/dashboard/event/${event.id}/transfer',
                              ),
                              child: Text(strings.open),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Member avatars row
                  _MembersPreview(
                    label: event.words.count('member', event.memberCount),
                    onTap: () =>
                        context.push('/dashboard/event/${event.id}/members'),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Edit Event tile — admin/owner only. Manage-then-add:
                  // sits above the Invite Members tile so admins reach
                  // the edit affordance first. Adds a discoverable body
                  // entry point alongside the gear icon in the hero
                  // (2026-06-11 iPhone 12 mini QA).
                  Consumer(
                    builder: (_, ref, _) {
                      final uid = ref.watch(currentUserIdProvider);
                      if (uid == null || !event.canManage(uid)) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: _QuickLinkCard(
                          key: const Key('eventDashboard.editEvent.tile'),
                          icon: AppIcons.actionEdit,
                          label: 'Edit Event',
                          subtitle: 'Update title, dates, or details',
                          color: AppColors.sage,
                          onTap: () =>
                              context.push('/dashboard/event/${event.id}/edit'),
                        ),
                      );
                    },
                  ),

                  // Invite Members tile — admin/owner only. Explicit
                  // null-uid guard so we don't rely on canManage('') semantics.
                  Consumer(
                    builder: (_, ref, _) {
                      final uid = ref.watch(currentUserIdProvider);
                      if (uid == null) return const SizedBox.shrink();
                      if (event.status == EventStatus.draft) {
                        if (!event.canManage(uid)) {
                          return const SizedBox.shrink();
                        }
                        final strings = context.strings.dashboard;
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: _QuickLinkCard(
                            key: const Key('events.dashboard.publish'),
                            icon: AppIcons.memberAdd,
                            label: strings.publishEvent,
                            subtitle: strings.publishEventSubtitle,
                            color: AppColors.terracotta,
                            onTap: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final result = await ref
                                  .read(eventRepositoryProvider)
                                  .setStatus(event.id, EventStatus.published);
                              if (result == EventWriteResult.failed) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(strings.publishFailed),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      }
                      // Inviting matches generateInviteCode: members.manage.
                      if (!event.isJoinable ||
                          !event.can(uid, 'members.manage')) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: _QuickLinkCard(
                          key: const Key('eventDashboard.inviteMembers.tile'),
                          icon: AppIcons.memberAdd,
                          label: context.strings.dashboard.inviteLabel(
                            event.words.other('member'),
                          ),
                          subtitle: 'Share a code to add people',
                          color: AppColors.terracotta,
                          onTap: () => AddMemberSheet.show(
                            context: context,
                            eventId: event.id,
                            memberLabel: event.words.other('member'),
                            canChooseRole: event.can(uid, 'roles.manage'),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  _ModuleHub(event: event),

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

/// One entry per enabled module, in a list that becomes a grid from 840 px. No
/// `extra:` payload, because child routes resolve the event by id via
/// EventGuard.
class _ModuleHub extends ConsumerWidget {
  const _ModuleHub({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.dashboard;
    final me = ref.watch(currentUserIdProvider) ?? '';
    Widget entry(
      String module,
      IconData icon,
      String label,
      String subtitle,
      Color color,
    ) => _QuickLinkCard(
      key: Key('events.hub.$module'),
      icon: icon,
      label: label,
      subtitle: subtitle,
      color: color,
      onTap: () => context.push('/dashboard/event/${event.id}/$module'),
    );

    final entries = [
      // Reading chat needs `chat.send` (Req 32).
      if (event.isModuleOn('chat') && event.readsChat(me))
        entry(
          'chat',
          AppIcons.navChatFilled,
          strings.moduleChat,
          strings.moduleChatSubtitle,
          AppColors.sage,
        ),
      if (event.isModuleOn('budget'))
        entry(
          'budget',
          AppIcons.navBudgetFilled,
          strings.moduleBudget,
          strings.moduleBudgetSubtitle,
          AppColors.terracotta,
        ),
      // Everyone's own agenda, then the whole schedule (Req 48, 51, 78b).
      if (event.isModuleOn('schedule'))
        entry(
          'agenda',
          AppIcons.schedule,
          context.strings.agenda.title,
          context.strings.agenda.hubSubtitle,
          Theme.of(context).colorScheme.secondary,
        ),
      if (event.isModuleOn('schedule'))
        entry(
          'schedule',
          AppIcons.calendar,
          context.strings.schedule.title,
          context.strings.schedule.hubSubtitle,
          Theme.of(context).colorScheme.tertiary,
        ),
      // The roster needs participants.read; a linked adult sees their own
      // group (Req 43).
      if (event.can(me, 'participants.read') || event.can(me, 'group.editOwn'))
        entry(
          'people',
          AppIcons.members,
          event.words.other('participant'),
          context.strings.people.hubSubtitle,
          Theme.of(context).colorScheme.primary,
        ),
      if (event.isModuleOn('tasks'))
        entry(
          'tasks',
          AppIcons.statusDone,
          strings.moduleTasks,
          strings.moduleTasksSubtitle,
          Theme.of(context).colorScheme.onSurface,
        ),
    ];

    if (entries.isEmpty) {
      return Text(strings.hubEmpty, key: const Key('events.hub.empty'));
    }
    if (MediaQuery.sizeOf(context).width < Breakpoints.mediumMax) {
      return Column(
        key: const Key('events.hub.list'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: entries,
      );
    }
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          key: const Key('events.hub.grid'),
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final card in entries) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _EventHero extends StatelessWidget {
  const _EventHero({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final dateLabel = formatEventDateRange(
      event.displayStart,
      event.displayEnd,
    );

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
              // Back button + mute toggle + settings (admin)
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
                  // Mute (Phase 5.1) — visible to every member; mute is
                  // a per-user choice so non-admins get it too.
                  Consumer(
                    builder: (_, ref, _) {
                      final uid = ref.watch(currentUserIdProvider);
                      if (uid == null) return const SizedBox.shrink();
                      final asyncMute = ref.watch(
                        eventMuteProvider((uid: uid, eventId: event.id)),
                      );
                      final mute = asyncMute.maybeWhen(
                        data: (m) => m,
                        orElse: () => null,
                      );
                      final isMuted =
                          mute != null &&
                          mute.isMutedAt(DateTime.now().toUtc());
                      return IconButton(
                        key: const Key('event.dashboard.muteIcon'),
                        tooltip: isMuted
                            ? 'Muted — tap to manage'
                            : 'Mute event',
                        icon: Icon(
                          isMuted
                              ? Icons.notifications_off_outlined
                              : Icons.notifications_outlined,
                          color: AppColors.offWhite,
                        ),
                        onPressed: () => MuteEventSheet.show(
                          context: context,
                          uid: uid,
                          eventId: event.id,
                        ),
                      );
                    },
                  ),
                  Consumer(
                    builder: (_, ref, _) {
                      final uid = ref.watch(currentUserIdProvider);
                      if (uid == null || !event.canManage(uid)) {
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

              // Event type badge, which newer events do not have.
              if (event.typeLabel != null) ...[
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
                    event.typeLabel!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.sageLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

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
              if (dateLabel.isNotEmpty)
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    const Icon(
                      AppIcons.calendar,
                      size: AppSizes.iconXs,
                      color: AppColors.sageLight,
                    ),
                    Flexible(
                      child: Consumer(
                        builder: (_, ref, _) {
                          // Named only where the viewer's device differs.
                          final note = zoneNoteFor(
                            event.timeZone,
                            ref.watch(deviceZoneNameProvider).value,
                            at: DateTime.now(),
                          );
                          return Text(
                            note == null ? dateLabel : '$dateLabel · $note',
                            key: const Key('events.dashboard.dates'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.sageLight),
                          );
                        },
                      ),
                    ),
                  ],
                ),

              // Status badge. Published is the normal state, so it has none.
              if (event.status != EventStatus.published) ...[
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
                    eventStatusLabel(context.strings.dashboard, event.status),
                    key: const Key('events.dashboard.status'),
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
  const _MembersPreview({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
        leading: const Icon(AppIcons.members, color: AppColors.sage),
        title: Text(label),
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
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
class _EventActions extends ConsumerStatefulWidget {
  const _EventActions({required this.event, required this.currentUserId});

  final EventModel event;
  final String currentUserId;

  @override
  ConsumerState<_EventActions> createState() => _EventActionsState();
}

class _EventActionsState extends ConsumerState<_EventActions> {
  bool _isLoading = false;

  /// The person's outstanding balance, or null if it is settled or cannot be
  /// worked out. Leaving is never blocked, so a failure here just skips the
  /// warning.
  Future<double?> _outstandingBalance() async {
    // Someone who cannot read every expense asks the server (Req 38c).
    if (!widget.event.readsAllExpenses(widget.currentUserId)) {
      try {
        final mine = await ref
            .read(myBalanceCallProvider)(widget.event.id)
            .timeout(const Duration(seconds: 3));
        return mine.net.abs() > 0.01 ? mine.net : null;
      } catch (_) {
        return null;
      }
    }
    // Keeps the stream listened to while this waits. A read with no listener
    // can leave the provider paused, and the wait would never finish.
    final subscription = ref.listenManual(
      expenseListProvider(widget.event.id).future,
      (_, _) {},
    );
    try {
      final expenses = await subscription.read().timeout(
        const Duration(seconds: 3),
      );
      final balance = BalanceLedger.calculate(
        expenses: expenses,
        memberIds: widget.event.memberIds,
      ).netBalances[widget.currentUserId];
      return balance != null && balance.abs() > 0.01 ? balance : null;
    } catch (_) {
      return null;
    } finally {
      subscription.close();
    }
  }

  /// A warning when leaving would leave at most one person who can invite
  /// and remove people (Req 31, H-07: there should always be a backup).
  /// Null when the person leaving cannot do it, or two or more others can.
  /// Member documents are read live; until they load, or on an event without
  /// them, no warning is shown. Leaving is never blocked.
  Future<String?> _managerWarning() async {
    final me = widget.currentUserId;
    final members = ref.read(eventMembersProvider(widget.event.id)).value;
    final holders = [
      for (final m in members ?? const <MemberModel>[])
        if (m.permissions.contains('members.manage')) m.uid,
    ];
    if (!holders.contains(me)) return null;
    final others = holders.where((uid) => uid != me).toList();
    final strings = context.strings.roles;
    if (others.isEmpty) return strings.leaveOnlyManagerWarning;
    if (others.length > 1) return null;
    String? name;
    try {
      final user = await ref
          .read(userRepositoryProvider)
          .watchEventProfile(widget.event.id, others.single)
          .first
          .timeout(const Duration(seconds: 2));
      name = (user?.displayName?.isNotEmpty ?? false)
          ? user!.displayName
          : null;
    } catch (_) {
      // The warning still shows, without the name.
    }
    return strings.leaveOneManagerLeftWarning(name);
  }

  Future<void> _leaveEvent() async {
    final balance = await _outstandingBalance();
    if (!mounted) return;
    final managerWarning = await _managerWarning();
    if (!mounted) return;
    final warning = balance == null
        ? null
        : context.strings.dashboard.leaveEventBalanceWarning(
            balance.abs().toStringAsFixed(2),
          );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Event?'),
        content: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: AppSpacing.sm,
          children: [
            const Text(
              'You will lose access to this event. '
              'Your past messages and expenses will remain.',
            ),
            if (warning != null)
              Text(
                warning,
                key: const Key('event.leave.balanceWarning'),
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            if (managerWarning != null)
              Text(
                managerWarning,
                key: const Key('event.leave.lastManagerWarning'),
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('event.leave.confirm'),
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
    // Kept listened to, so the leave dialog knows who else manages members.
    ref.watch(eventMembersProvider(widget.event.id));
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(child: LoadingAnimation()),
      );
    }

    final uid = widget.currentUserId;
    final isOwner = widget.event.isOwner(uid);
    // Deleting is the Owner's, through `event.transfer`.
    final canDelete = widget.event.can(uid, 'event.transfer');

    return Column(
      crossAxisAlignment: .start,
      spacing: AppSpacing.md,
      children: [
        if (widget.event.canManage(widget.currentUserId))
          Card(
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
              key: const Key('events.dashboard.settings'),
              leading: const Icon(AppIcons.actionSettings),
              title: Text(context.strings.dashboard.settingsTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push('/dashboard/event/${widget.event.id}/settings'),
            ),
          ),

        // Archive toggle (`event.manage`)
        if (widget.event.canManage(uid))
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                        : widget.event.restoredStatus(DateTime.now()),
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
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderLg,
              side: BorderSide(
                color: AppColors.lightGrey.withValues(alpha: 0.7),
                width: 0.5,
              ),
            ),
            child: ListTile(
              key: const Key('event.action.leave'),
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
        if (canDelete) ...[
          const SizedBox(height: AppSpacing.lg),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
