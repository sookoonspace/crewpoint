import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap});

  final EventModel event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: .start,
            spacing: AppSpacing.xs,
            children: [
              Text(event.title, style: Theme.of(context).textTheme.titleMedium),
              if (event.description != null)
                Text(
                  event.description!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (event.startDate != null)
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppColors.mediumGrey,
                    ),
                    Text(
                      dateFormat.format(event.startDate!),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.mediumGrey,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
