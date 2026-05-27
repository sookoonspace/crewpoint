import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/empty_state_placeholder.dart';
import 'package:crewpoint_app/app/core/widgets/screen_header.dart';
import 'package:crewpoint_app/app/core/widgets/section_label.dart';
import 'package:crewpoint_app/app/core/widgets/segmented_filter_bar.dart';
import 'package:crewpoint_app/app/core/widgets/skeletons.dart';
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
    final boundary = e.endDate ?? e.startDate;
    if (boundary == null) return false;
    return boundary.isBefore(DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
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
    // Greeting uses a Material wave icon rather than the 👋 emoji —
    // some fonts (Poppins via GoogleFonts) and the iOS Simulator render
    // the emoji as a "missing glyph" box.
    final greeting = '${_greetingPrefix(s, now)}, $firstName';
    final dateLine = DateFormat('EEEE, MMM d').format(now);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              key: const Key('dashboard.header'),
              title: greeting,
              subtitle: dateLine,
              actions: [
                IconButton(
                  key: const Key('dashboard.header.joinEvent'),
                  tooltip: s.joinEventTooltip,
                  icon: const Icon(AppIcons.joinEvent),
                  onPressed: () => JoinEventSheet.show(context: context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: SegmentedFilterBar<DashboardFilter>(
                key: const Key('dashboard.filter'),
                selected: _filter,
                equalWidth: true,
                segments: [
                  SegmentedFilterSegment(
                    value: DashboardFilter.upcoming,
                    label: s.filterUpcoming,
                    keyValue: const Key('dashboard.filter.upcoming'),
                  ),
                  SegmentedFilterSegment(
                    value: DashboardFilter.past,
                    label: s.filterPast,
                    keyValue: const Key('dashboard.filter.past'),
                  ),
                ],
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('dashboard.action.createEvent'),
                  onPressed: () => context.push('/dashboard/create'),
                  icon: const Icon(AppIcons.actionAdd),
                  label: Text(s.createEventCta),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ContentMaxWidth(
                key: const Key('dashboard.body.clamped'),
                maxWidth: 720,
                child: eventsAsync.when(
                  loading: () => ListView.separated(
                    key: const Key('dashboard.events.loading'),
                    padding: EdgeInsets.symmetric(
                      horizontal: Breakpoints.screenHorizontalPadding(context),
                      vertical: AppSpacing.lg,
                    ),
                    itemCount: 3,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, _) => const EventTileSkeleton(),
                  ),
                  error: (e, _) => _ErrorState(
                    onRetry: () => ref.invalidate(dashboardEventsProvider),
                  ),
                  data: (events) {
                    final partitioned = events
                        .where(
                          (e) => _filter == DashboardFilter.past
                              ? _isPast(e, now)
                              : !_isPast(e, now),
                        )
                        .toList();
                    if (partitioned.isEmpty) {
                      return EmptyStatePlaceholder(
                        title: s.noEventsTitle,
                        subtitle: s.noEventsSubtitle,
                        ctaLabel: s.joinWithCode,
                        iconFallback: AppIcons.event,
                        onCta: () => JoinEventSheet.show(context: context),
                      );
                    }
                    return ListView.separated(
                      key: const Key('dashboard.events.list'),
                      padding: EdgeInsets.symmetric(
                        horizontal: Breakpoints.screenHorizontalPadding(
                          context,
                        ),
                        vertical: AppSpacing.lg,
                      ),
                      itemCount: partitioned.length + 1,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, index) {
                        if (index == 0) {
                          final label = _filter == DashboardFilter.upcoming
                              ? s.upcomingEventsHeader(partitioned.length)
                              : s.pastEventsHeader(partitioned.length);
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: SectionLabel(label),
                          );
                        }
                        final event = partitioned[index - 1];
                        return EventCard(
                          event: event,
                          onTap: () =>
                              context.push('/dashboard/event/${event.id}'),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.dashboard;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: [
            Text(
              s.errorLoading,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            OutlinedButton.icon(
              key: const Key('dashboard.error.retry'),
              onPressed: onRetry,
              icon: const Icon(AppIcons.actionRetry),
              label: Text(s.retryCta),
            ),
          ],
        ),
      ),
    );
  }
}
