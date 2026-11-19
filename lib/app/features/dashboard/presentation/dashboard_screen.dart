import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/greeting_first_name.dart';
import 'package:crewpoint_app/app/features/profile/application/current_user_doc_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_card.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/join_event_sheet.dart';

enum DashboardFilter { upcoming, past }

String _greetingPrefix(DashboardStrings s, DateTime now) {
  final h = now.hour;
  if (h < 12) return s.greetingMorning;
  if (h < 17) return s.greetingAfternoon;
  return s.greetingEvening;
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardFilter _filter = DashboardFilter.upcoming;

  bool _isPast(EventModel e, DateTime now) {
    return e.isPast(now);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final eventsAsync = ref.watch(dashboardEventsProvider);
    // Read the merged user doc; falls back to null on loading/error so the
    // greeting stays grammatical even when auth/Firestore aren't ready.
    final userAsync = ref.watch(currentUserDocProvider);
    final displayName = userAsync.maybeWhen(
      data: (user) => user?.displayName,
      orElse: () => null,
    );
    final now = clock.now();
    final firstName = greetingFirstName(displayName);
    final s = context.strings.dashboard;
    final home = context.strings.eventHome;
    final greeting = '${_greetingPrefix(s, now)}, $firstName';
    final dateLine = DateFormat('EEEE, MMM d').format(now);
    final padding = EdgeInsets.symmetric(horizontal: cp.space.lg);

    Widget section(String title, List<EventModel> events) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.sm,
      children: [
        CpSectionHeader(title: title, trailingText: '${events.length}'),
        for (final event in events)
          EventCard(
            event: event,
            onTap: () => context.push('/dashboard/event/${event.id}'),
          ),
      ],
    );

    final Widget body = eventsAsync.when(
      loading: () => ListView(
        key: const Key('dashboard.events.loading'),
        padding: padding.copyWith(top: cp.space.lg),
        children: [CpLoadingState.rows(semanticLabel: s.errorLoading, rows: 3)],
      ),
      error: (e, _) => CpErrorState(
        title: s.errorLoading,
        retryLabel: s.retryCta,
        retryKey: const Key('dashboard.error.retry'),
        onRetry: () => ref.invalidate(dashboardEventsProvider),
      ),
      data: (events) {
        final shown = events
            .where(
              (e) => _filter == DashboardFilter.past
                  ? _isPast(e, now)
                  : !_isPast(e, now),
            )
            .toList();
        if (shown.isEmpty) {
          return SingleChildScrollView(
            child: CpEmptyState(
              icon: CpIcons.event,
              title: s.noEventsTitle,
              message: s.noEventsSubtitle,
              actionLabel: s.joinWithCode,
              actionKey: const Key('dashboard.empty.join'),
              onAction: () => JoinEventSheet.show(context: context),
            ),
          );
        }
        // Upcoming groups what is on now, what is coming and drafts; past
        // events are one list.
        final sections = _filter == DashboardFilter.past
            ? [(home.past, shown)]
            : [
                (
                  home.happeningNow,
                  [
                    for (final e in shown)
                      if (e.status == EventStatus.live) e,
                  ],
                ),
                (
                  home.upcoming,
                  [
                    for (final e in shown)
                      if (e.status != EventStatus.live &&
                          e.status != EventStatus.draft)
                        e,
                  ],
                ),
                (
                  home.drafts,
                  [
                    for (final e in shown)
                      if (e.status == EventStatus.draft) e,
                  ],
                ),
              ];
        return ListView(
          key: const Key('dashboard.events.list'),
          padding: padding.copyWith(top: cp.space.sm, bottom: cp.space.xxl),
          children: [
            for (final (title, list) in sections)
              if (list.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: cp.space.xl),
                  child: section(title, list),
                ),
          ],
        );
      },
    );

    return Scaffold(
      appBar: CpTopBar(
        key: const Key('dashboard.header'),
        actions: [
          CpTopBarAction(
            key: const Key('dashboard.header.joinEvent'),
            icon: CpIcons.joinEvent,
            tooltip: s.joinEventTooltip,
            onPressed: () => JoinEventSheet.show(context: context),
          ),
          CpTopBarAction(
            key: const Key('dashboard.action.createEvent'),
            icon: CpIcons.actionAdd,
            tooltip: home.createEvent,
            primary: true,
            onPressed: () => context.push('/dashboard/create'),
          ),
        ],
      ),
      body: ContentMaxWidth(
        key: const Key('dashboard.body.clamped'),
        maxWidth: cp.sizes.phoneColumn + 2 * cp.space.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: cp.space.xs,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      greeting,
                      style: cp.type.headlineLarge.copyWith(
                        color: cp.colors.text,
                      ),
                    ),
                  ),
                  Text(
                    dateLine,
                    style: cp.type.bodyMedium.copyWith(
                      color: cp.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: padding.copyWith(top: cp.space.lg, bottom: cp.space.md),
              child: CpSegmented<DashboardFilter>(
                key: const Key('dashboard.filter'),
                semanticLabel: home.upcoming,
                choices: [
                  CpChoice(
                    DashboardFilter.upcoming,
                    s.filterUpcoming,
                    key: const Key('dashboard.filter.upcoming'),
                  ),
                  CpChoice(
                    DashboardFilter.past,
                    s.filterPast,
                    key: const Key('dashboard.filter.past'),
                  ),
                ],
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
