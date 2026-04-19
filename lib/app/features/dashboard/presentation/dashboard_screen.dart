import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.events,
    this.onCreateEvent,
    this.onEventTap,
  });

  final List<EventModel> events;
  final VoidCallback? onCreateEvent;
  final ValueChanged<EventModel>? onEventTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: events.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, index) => EventCard(
                event: events[index],
                onTap: () => onEventTap?.call(events[index]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: onCreateEvent,
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
            'Tap + to create your first event',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGrey),
          ),
        ],
      ),
    );
  }
}
