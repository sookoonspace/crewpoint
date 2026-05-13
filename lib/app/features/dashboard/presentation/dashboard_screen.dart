import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/empty_state_placeholder.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_card.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/join_event_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(dashboardEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: AppColors.cream,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.login_rounded),
            tooltip: 'Join Event',
            onPressed: () => JoinEventSheet.show(context: context),
          ),
        ],
      ),
      body: ContentMaxWidth(
        key: const Key('dashboard.body.clamped'),
        maxWidth: 720,
        child: eventsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                "Couldn't load your events.",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.darkGrey),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (events) {
            if (events.isEmpty) {
              final s = context.strings.dashboard;
              return EmptyStatePlaceholder(
                title: s.noEventsTitle,
                subtitle: s.noEventsSubtitle,
                ctaLabel: s.joinWithCode,
                onCta: () => JoinEventSheet.show(context: context),
              );
            }
            return ListView.separated(
              key: const Key('dashboard.events.list'),
              padding: EdgeInsets.symmetric(
                horizontal: Breakpoints.screenHorizontalPadding(context),
                vertical: AppSpacing.xl,
              ),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, index) => EventCard(
                event: events[index],
                onTap: () =>
                    context.push('/dashboard/event/${events[index].id}'),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/dashboard/create'),
        backgroundColor: AppColors.sage,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
