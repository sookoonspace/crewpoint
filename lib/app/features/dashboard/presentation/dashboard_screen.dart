import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_card.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/join_event_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Wire to event provider when Firestore sync is implemented
    // For now, show empty state with create + join actions
    final events = <EventModel>[];

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
      body: events.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, index) => EventCard(
                event: events[index],
                onTap: () =>
                    context.push('/dashboard/event/${events[index].id}'),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: .center,
        spacing: AppSpacing.lg,
        children: [
          const Icon(Icons.event_note, size: 64, color: AppColors.lightGrey),
          Text(
            'No events yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.mediumGrey),
          ),
          Text(
            'Create an event or join one with a code',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGrey),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => JoinEventSheet.show(context: context),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Join with Code'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.sage,
              side: const BorderSide(color: AppColors.sage),
            ),
          ),
        ],
      ),
    );
  }
}
