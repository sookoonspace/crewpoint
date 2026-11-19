import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/layout/breakpoints.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/format/event_date_range.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/member.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/add_member_sheet.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_cover.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_status_label.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/mute_event_sheet.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:crewpoint_app/app/features/tasks/application/event_task_counts_provider.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// The Event home (Spec #186, #199): the cover, the event at a glance, what
/// is next and what is open, then its sections and admin actions. From
/// 840 px it is a dashboard grid: summary cards in a row, the next sessions
/// and open tasks side by side.
class EventDashboardScreen extends StatelessWidget {
  const EventDashboardScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.mediumMax;
    final gap = SizedBox(height: cp.space.xl);
    return Scaffold(
      appBar: _EventTopBar(event: event),
      body: ListView(
        key: const Key('eventDashboard.list'),
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.xs,
          cp.space.lg,
          cp.space.xxl,
        ),
        children: [
          ContentMaxWidth(
            key: const Key('eventDashboard.body.clamped'),
            maxWidth: wide ? 960 : cp.sizes.phoneColumn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EventCoverBanner(
                  event: event,
                  height: wide ? cp.sizes.coverBannerWide : null,
                ),
                SizedBox(height: cp.space.lg),
                _Head(event: event, wide: wide),
                _OwnershipOffer(event: event),
                gap,
                _Stats(event: event),
                gap,
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: cp.space.lg + cp.space.xs,
                    children: [
                      if (event.isModuleOn('schedule'))
                        Expanded(child: _UpNext(event: event)),
                      if (event.isModuleOn('tasks'))
                        Expanded(child: _OpenTasks(event: event)),
                    ],
                  )
                else ...[
                  if (event.isModuleOn('schedule')) ...[
                    _UpNext(event: event),
                    gap,
                  ],
                  if (event.isModuleOn('tasks')) _OpenTasks(event: event),
                ],
                gap,
                CpSectionHeader(title: context.strings.eventHome.eventSection),
                SizedBox(height: cp.space.sm),
                _ModuleHub(event: event),
                _Manage(event: event),
                gap,
                Consumer(
                  builder: (_, ref, _) => _EventActions(
                    event: event,
                    currentUserId: ref.watch(currentUserIdProvider) ?? '',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Back, mute (everyone) and settings (`event.manage`).
class _EventTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _EventTopBar({required this.event});

  final EventModel event;

  @override
  Size get preferredSize => const CpTopBar().preferredSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.eventHome;
    final uid = ref.watch(currentUserIdProvider);
    final mute = uid == null
        ? null
        : ref.watch(eventMuteProvider((uid: uid, eventId: event.id))).value;
    final isMuted = mute != null && mute.isMutedAt(DateTime.now().toUtc());
    return CpTopBar(
      leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
      leadingKey: const Key('event.dashboard.back'),
      onLeading: () => context.pop(),
      actions: [
        // Muting is each person's own choice (Phase 5.1).
        if (uid != null)
          CpTopBarAction(
            key: const Key('event.dashboard.muteIcon'),
            icon: isMuted ? CpIcons.actionMute : CpIcons.notifications,
            tooltip: isMuted ? strings.muted : strings.mute,
            onPressed: () => MuteEventSheet.show(
              context: context,
              uid: uid,
              eventId: event.id,
            ),
          ),
        if (uid != null && event.canManage(uid))
          CpTopBarAction(
            key: const Key('event.dashboard.settingsIcon'),
            icon: CpIcons.actionSettings,
            tooltip: strings.editEvent,
            onPressed: () => context.push('/dashboard/event/${event.id}/edit'),
          ),
      ],
    );
  }
}

/// Status, title, dates, place and description. How many people are in
/// it is the first summary card.
class _Head extends ConsumerWidget {
  const _Head({required this.event, required this.wide});

  final EventModel event;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final dates = formatEventDateRange(event.displayStart, event.displayEnd);
    // The time zone is named only where the viewer's device differs.
    final note = zoneNoteFor(
      event.timeZone,
      ref.watch(deviceZoneNameProvider).value,
      at: DateTime.now(),
    );
    final place = event.venues.isEmpty ? null : event.venues.first.name;
    final status = eventStatusLabel(context.strings.dashboard, event.status);
    Widget meta(IconData icon, String text, {Key? key}) => Row(
      key: key,
      spacing: cp.space.sm,
      children: [
        Icon(icon, size: cp.sizes.iconSm + 1, color: cp.colors.textMuted),
        Flexible(
          child: Text(
            text,
            style: cp.type.bodySmall.copyWith(
              color: cp.colors.textMuted,
              fontSize: cp.type.titleSmall.fontSize! - 1,
            ),
          ),
        ),
      ],
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.sm,
      children: [
        CpTag(
          key: const Key('events.dashboard.status'),
          label: status,
          dot: event.status == EventStatus.live,
          tone:
              event.status == EventStatus.draft ||
                  event.status == EventStatus.archived
              ? CpTagTone.quiet
              : CpTagTone.accent,
        ),
        Semantics(
          header: true,
          child: Text(
            event.title,
            style: (wide ? cp.type.displaySmall : cp.type.headlineLarge)
                .copyWith(color: cp.colors.text),
          ),
        ),
        if (dates.isNotEmpty)
          meta(
            CpIcons.calendar,
            note == null ? dates : '$dates · $note',
            key: const Key('events.dashboard.dates'),
          ),
        ?(place == null ? null : meta(CpIcons.place, place)),
        if (event.description != null && event.description!.isNotEmpty)
          Text(
            event.description!,
            style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
          ),
      ],
    );
    return details;
  }
}

/// Shown to the person offered ownership (Req 30).
class _OwnershipOffer extends ConsumerWidget {
  const _OwnershipOffer({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final offer = ref.watch(ownershipOfferProvider(event.id)).value;
    if (uid == null || offer == null || offer.to != uid) {
      return const SizedBox.shrink();
    }
    final cp = context.cp;
    final strings = context.strings.transfer;
    return Padding(
      padding: EdgeInsets.only(top: cp.space.lg),
      child: CpCard(
        key: const Key('event.ownershipOffer'),
        padding: EdgeInsets.all(cp.space.lg),
        child: Row(
          spacing: cp.space.md,
          children: [
            Icon(CpIcons.actionSwap, color: cp.colors.accent),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.title,
                    style: cp.type.titleSmall.copyWith(color: cp.colors.text),
                  ),
                  Text(
                    strings.bannerBody,
                    style: cp.type.bodySmall.copyWith(
                      color: cp.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            CpButton.text(
              key: const Key('event.ownershipOffer.open'),
              label: strings.open,
              onPressed: () =>
                  context.push('/dashboard/event/${event.id}/transfer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// People, tasks and money at a glance.
class _Stats extends ConsumerWidget {
  const _Stats({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.eventHome;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final counts = event.isModuleOn('tasks')
        ? ref.watch(eventTaskCountsProvider(event.id)).value
        : null;
    // Spending only for someone who reads every expense (Req 38c).
    final expenses = event.isModuleOn('budget') && event.readsAllExpenses(me)
        ? ref.watch(expenseListProvider(event.id)).value
        : null;
    final total = counts == null ? 0 : counts.todo + counts.doing + counts.done;
    return CpStatGrid(
      children: [
        CpStatCard(
          key: const Key('events.dashboard.stat.members'),
          icon: CpIcons.members,
          label: event.words.other('member'),
          value: '${event.memberCount}',
          onTap: () => context.push('/dashboard/event/${event.id}/members'),
        ),
        if (event.isModuleOn('tasks'))
          CpStatCard(
            key: const Key('events.dashboard.stat.tasks'),
            icon: CpIcons.tasks,
            label: strings.tasks,
            value: counts == null ? '…' : '${counts.done}/$total',
            progress: total == 0 ? null : counts!.done / total,
            progressLabel: total == 0
                ? null
                : strings.tasksDone(counts!.done, total),
            caption: counts == null
                ? null
                : total == 0
                ? strings.noTasks
                : strings.openCount(counts.todo + counts.doing),
            onTap: () => context.push('/dashboard/event/${event.id}/tasks'),
          ),
        if (expenses != null)
          CpStatCard(
            key: const Key('events.dashboard.stat.budget'),
            icon: CpIcons.budget,
            label: strings.budget,
            value: NumberFormat.simpleCurrency(
              name: event.currency,
              decimalDigits: 0,
            ).format(expenses.fold<double>(0, (sum, e) => sum + e.amount)),
            caption: strings.expenseCount(expenses.length),
            onTap: () => context.push('/dashboard/event/${event.id}/budget'),
          ),
      ],
    );
  }
}

/// The next three sessions, in the event's time zone.
class _UpNext extends ConsumerWidget {
  const _UpNext({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.eventHome;
    final now = DateTime.now().toUtc();
    final sessions = [
      for (final s
          in ref.watch(sessionListProvider(event.id)).value ??
              const <SessionModel>[])
        // A session with no end lasts an hour (#82).
        if (!s.hidden &&
            (s.endAt ?? s.startAt.add(const Duration(hours: 1))).isAfter(now))
          s,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    final venues = {for (final v in event.venues) v.id: v.name};
    return Column(
      key: const Key('events.dashboard.upNext'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.sm,
      children: [
        CpSectionHeader(
          title: strings.upNext,
          actionLabel: strings.scheduleLink,
          actionKey: const Key('events.dashboard.upNext.schedule'),
          onAction: () => context.push('/dashboard/event/${event.id}/schedule'),
        ),
        CpCard(
          child: sessions.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(cp.space.lg),
                  child: Text(
                    strings.nothingNext,
                    style: cp.type.bodySmall.copyWith(
                      color: cp.colors.textMuted,
                    ),
                  ),
                )
              : CpRowGroup(
                  children: [
                    for (final s in sessions.take(3))
                      CpListRow(
                        key: Key('events.dashboard.session.${s.id}'),
                        leading: _Time(at: event.inZone(s.startAt)),
                        title: s.title,
                        subtitle: venues[s.venueId],
                        onTap: () => context.push(
                          '/dashboard/event/${event.id}/schedule/${s.id}',
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Time extends StatelessWidget {
  const _Time({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    // Split on any space: `jm` puts a narrow no-break space before AM/PM.
    final parts = DateFormat.jm().format(at).split(RegExp(r'\s'));
    return SizedBox(
      width: cp.sizes.tapMin + cp.space.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parts.first,
            style: cp.type.titleSmall.copyWith(
              color: cp.colors.text,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (parts.length > 1)
            Text(
              parts.skip(1).join(' '),
              style: cp.type.labelSmall.copyWith(
                color: cp.colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// The three most pressing open tasks, with their status.
class _OpenTasks extends ConsumerWidget {
  const _OpenTasks({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.eventHome;
    final today = DateUtils.dateOnly(DateTime.now());
    final open =
        [
          for (final t
              in ref.watch(taskListProvider(event.id)).value ??
                  const <TaskModel>[])
            if (t.status != TaskStatus.done) t,
        ]..sort((a, b) {
          final x = a.dueDate;
          final y = b.dueDate;
          // Tasks without a due date go last.
          if (x == null || y == null) {
            return x == null ? (y == null ? 0 : 1) : -1;
          }
          return x.compareTo(y);
        });
    Widget? chip(TaskModel t) {
      final due = t.dueDate;
      if (due == null) return null;
      final day = DateUtils.dateOnly(due.toLocal());
      if (day.isBefore(today)) {
        return CpStatusChip(status: CpStatus.overdue, label: strings.overdue);
      }
      if (day.difference(today).inDays < 7) {
        return CpStatusChip(
          status: CpStatus.due,
          label: strings.due(DateFormat.E().format(day)),
        );
      }
      return null;
    }

    return Column(
      key: const Key('events.dashboard.openTasks'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.sm,
      children: [
        CpSectionHeader(
          title: strings.openTasks,
          actionLabel: strings.allTasks,
          actionKey: const Key('events.dashboard.openTasks.all'),
          onAction: () => context.push('/dashboard/event/${event.id}/tasks'),
        ),
        CpCard(
          child: open.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(cp.space.lg),
                  child: Text(
                    strings.noOpenTasks,
                    style: cp.type.bodySmall.copyWith(
                      color: cp.colors.textMuted,
                    ),
                  ),
                )
              : CpRowGroup(
                  children: [
                    for (final t in open.take(3))
                      CpListRow(
                        key: Key('events.dashboard.task.${t.id}'),
                        title: t.title,
                        subtitle: t.dueDate == null
                            ? null
                            : DateFormat.MMMEd().format(t.dueDate!.toLocal()),
                        trailing: chip(t),
                        onTap: () => context.push(
                          '/dashboard/event/${event.id}/tasks/${t.id}',
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// One entry per enabled module: two to a row on a phone, three from
/// 840 px. Child routes resolve the event by ID through EventGuard.
class _ModuleHub extends ConsumerWidget {
  const _ModuleHub({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.dashboard;
    final me = ref.watch(currentUserIdProvider) ?? '';
    Widget entry(String module, IconData icon, String label, String subtitle) =>
        _HubTile(
          key: Key('events.hub.$module'),
          icon: icon,
          label: label,
          subtitle: subtitle,
          onTap: () => context.push('/dashboard/event/${event.id}/$module'),
        );

    final entries = [
      // Reading chat needs `chat.send` (Req 32).
      if (event.isModuleOn('chat') && event.readsChat(me))
        entry(
          'chat',
          CpIcons.chat,
          strings.moduleChat,
          strings.moduleChatSubtitle,
        ),
      if (event.isModuleOn('budget'))
        entry(
          'budget',
          CpIcons.budget,
          strings.moduleBudget,
          strings.moduleBudgetSubtitle,
        ),
      // Everyone's own agenda, then the whole schedule (Req 48, 51, 78b).
      if (event.isModuleOn('schedule'))
        entry(
          'agenda',
          CpIcons.agenda,
          context.strings.agenda.title,
          context.strings.agenda.hubSubtitle,
        ),
      if (event.isModuleOn('schedule'))
        entry(
          'schedule',
          CpIcons.schedule,
          context.strings.schedule.title,
          context.strings.schedule.hubSubtitle,
        ),
      // The roster needs participants.read; a linked adult sees their own
      // group (Req 43).
      if (event.can(me, 'participants.read') || event.can(me, 'group.editOwn'))
        entry(
          'people',
          CpIcons.members,
          event.words.other('participant'),
          context.strings.people.hubSubtitle,
        ),
      // Headcounts need counts.read (Req 52).
      if (event.can(me, 'counts.read'))
        entry(
          'counts',
          CpIcons.counts,
          context.strings.counts.title,
          context.strings.counts.hubSubtitle,
        ),
      if (event.isModuleOn('tasks'))
        entry(
          'tasks',
          CpIcons.tasks,
          strings.moduleTasks,
          strings.moduleTasksSubtitle,
        ),
    ];

    if (entries.isEmpty) {
      return Text(
        strings.hubEmpty,
        key: const Key('events.hub.empty'),
        style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.mediumMax;
    return LayoutBuilder(
      key: Key(wide ? 'events.hub.grid' : 'events.hub.list'),
      builder: (context, constraints) {
        // As many to a row as fit, never more than three, so a tile's text
        // is never squeezed at large text sizes.
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final fit =
            ((constraints.maxWidth + cp.space.sm) /
                    (cp.sizes.statMinHeight * 1.5 * scale + cp.space.sm))
                .floor();
        final columns = fit.clamp(1, wide ? 3 : 2);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: cp.space.sm,
          children: [
            for (var start = 0; start < entries.length; start += columns)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: cp.space.sm,
                  children: [
                    for (var i = start; i < start + columns; i++)
                      Expanded(
                        child: i < entries.length
                            ? entries[i]
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return CpCard(
      onTap: onTap,
      semanticLabel: '$label, $subtitle',
      padding: EdgeInsets.symmetric(
        horizontal: cp.space.md,
        vertical: cp.space.md + 2,
      ),
      child: Row(
        spacing: cp.space.md - 2,
        children: [
          Container(
            width: cp.sizes.iconTile,
            height: cp.sizes.iconTile,
            decoration: BoxDecoration(
              color: cp.colors.accentSoft,
              borderRadius: cp.radii.sm,
            ),
            child: Icon(icon, size: cp.sizes.iconMd, color: cp.colors.accent),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: cp.type.titleSmall.copyWith(color: cp.colors.text),
                ),
                Text(
                  subtitle,
                  style: cp.type.labelSmall.copyWith(
                    color: cp.colors.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Editing, publishing a draft and inviting, for those who may.
class _Manage extends ConsumerWidget {
  const _Manage({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.eventHome;
    final dashboard = context.strings.dashboard;
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return const SizedBox.shrink();
    Widget icon(IconData glyph) => Container(
      width: cp.sizes.iconTile,
      height: cp.sizes.iconTile,
      decoration: BoxDecoration(
        color: cp.colors.accentSoft,
        borderRadius: cp.radii.sm,
      ),
      child: Icon(glyph, size: cp.sizes.iconMd, color: cp.colors.accent),
    );
    final rows = <Widget>[
      if (event.canManage(uid))
        CpListRow(
          key: const Key('eventDashboard.editEvent.tile'),
          leading: icon(CpIcons.actionEdit),
          title: strings.editEvent,
          subtitle: strings.editEventSubtitle,
          onTap: () => context.push('/dashboard/event/${event.id}/edit'),
        ),
      // A draft is published before anyone is invited (Req 19).
      if (event.status == EventStatus.draft && event.canManage(uid))
        CpListRow(
          key: const Key('events.dashboard.publish'),
          leading: icon(CpIcons.memberAdd),
          title: dashboard.publishEvent,
          subtitle: dashboard.publishEventSubtitle,
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final result = await ref
                .read(eventRepositoryProvider)
                .setStatus(event.id, EventStatus.published);
            if (result == EventWriteResult.failed) {
              messenger.showSnackBar(
                SnackBar(content: Text(dashboard.publishFailed)),
              );
            }
          },
        ),
      // Inviting matches generateInviteCode: members.manage.
      if (event.status != EventStatus.draft &&
          event.isJoinable &&
          event.can(uid, 'members.manage'))
        CpListRow(
          key: const Key('eventDashboard.inviteMembers.tile'),
          leading: icon(CpIcons.memberAdd),
          title: dashboard.inviteLabel(event.words.other('member')),
          subtitle: strings.inviteSubtitle,
          onTap: () => AddMemberSheet.show(
            context: context,
            eventId: event.id,
            memberLabel: event.words.other('member'),
            canChooseRole: event.can(uid, 'roles.manage'),
          ),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: cp.space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.sm,
        children: [
          CpSectionHeader(title: strings.manageSection),
          CpCard(child: CpRowGroup(children: rows)),
        ],
      ),
    );
  }
}

/// Settings, archive, leave and delete.
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

  void _fail(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _leaveEvent() async {
    final balance = await _outstandingBalance();
    if (!mounted) return;
    final managerWarning = await _managerWarning();
    if (!mounted) return;
    final strings = context.strings.eventHome;
    final warning = balance == null
        ? null
        : context.strings.dashboard.leaveEventBalanceWarning(
            balance.abs().toStringAsFixed(2),
          );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cp = ctx.cp;
        Widget warn(String text, Key key) => Text(
          text,
          key: key,
          style: cp.type.bodyMedium.copyWith(color: cp.colors.overdue),
        );
        return CpDialog(
          title: strings.leaveTitle,
          message: strings.leaveBody,
          content: warning == null && managerWarning == null
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: cp.space.sm,
                  children: [
                    if (warning != null)
                      warn(warning, const Key('event.leave.balanceWarning')),
                    if (managerWarning != null)
                      warn(
                        managerWarning,
                        const Key('event.leave.lastManagerWarning'),
                      ),
                  ],
                ),
          actions: [
            CpButton.text(
              label: strings.cancel,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            CpButton.destructive(
              key: const Key('event.leave.confirm'),
              label: strings.leave,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
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
        _fail(strings.leaveFailed);
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    required bool destructive,
  }) async {
    final strings = context.strings.eventHome;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CpDialog(
        title: title,
        message: body,
        actions: [
          CpButton.text(
            label: strings.cancel,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          if (destructive)
            CpButton.destructive(
              label: action,
              onPressed: () => Navigator.pop(ctx, true),
            )
          else
            CpButton.text(
              label: action,
              onPressed: () => Navigator.pop(ctx, true),
            ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteEvent() async {
    final strings = context.strings.eventHome;
    // A warning, then a final confirmation.
    if (!await _confirm(
          title: strings.deleteTitle,
          body: strings.deleteBody,
          action: strings.continueLabel,
          destructive: false,
        ) ||
        !mounted) {
      return;
    }
    if (!await _confirm(
          title: strings.confirmTitle,
          body: strings.confirmBody,
          action: strings.deleteForever,
          destructive: true,
        ) ||
        !mounted) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteEvent');
      await callable.call<Map<String, dynamic>>({'eventId': widget.event.id});
      if (mounted) context.go('/dashboard');
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _fail(strings.deleteFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kept listened to, so the leave dialog knows who else manages members.
    ref.watch(eventMembersProvider(widget.event.id));
    final cp = context.cp;
    final strings = context.strings.eventHome;
    if (_isLoading) {
      return CpLoadingState(semanticLabel: strings.leaveEvent);
    }

    final uid = widget.currentUserId;
    final event = widget.event;
    final isOwner = event.isOwner(uid);
    // Deleting is the Owner's, through `event.transfer`.
    final canDelete = event.can(uid, 'event.transfer');
    final archived = event.status == EventStatus.archived;

    final rows = <Widget>[
      if (event.canManage(uid))
        CpListRow(
          key: const Key('events.dashboard.settings'),
          leading: Icon(CpIcons.actionSettings, color: cp.colors.textMuted),
          title: context.strings.dashboard.settingsTitle,
          onTap: () => context.push('/dashboard/event/${event.id}/settings'),
        ),
      if (event.canManage(uid))
        Padding(
          padding: EdgeInsets.symmetric(horizontal: cp.space.lg),
          child: CpSwitchRow(
            key: const Key('events.dashboard.archive'),
            title: strings.archiveEvent,
            help: archived ? strings.archived : strings.archiveHelp,
            value: archived,
            onChanged: (value) async {
              final messenger = ScaffoldMessenger.of(context);
              final updated = event.copyWith(
                status: value
                    ? EventStatus.archived
                    : event.restoredStatus(DateTime.now()),
              );
              final ok = await ref
                  .read(eventRepositoryProvider)
                  .updateEvent(updated);
              if (!ok) {
                messenger.showSnackBar(
                  SnackBar(content: Text(strings.archiveFailed)),
                );
              }
            },
          ),
        ),
      // Everyone but the Owner can leave.
      if (!isOwner)
        CpListRow(
          key: const Key('event.action.leave'),
          leading: Icon(CpIcons.actionLogout, color: cp.colors.textMuted),
          title: strings.leaveEvent,
          onTap: _leaveEvent,
        ),
      if (canDelete)
        CpListRow(
          key: const Key('event.action.delete'),
          leading: Icon(
            CpIcons.actionDeletePermanent,
            color: cp.colors.overdue,
          ),
          title: strings.deleteEvent,
          onTap: _deleteEvent,
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return CpCard(child: CpRowGroup(children: rows));
  }
}
