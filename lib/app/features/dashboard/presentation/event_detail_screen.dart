import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_sizes.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMMd();
    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: .start,
          spacing: AppSpacing.lg,
          children: [
            if (event.description != null)
              Text(
                event.description!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            if (event.startDate != null)
              _DetailRow(
                icon: AppIcons.calendar,
                label: 'Start',
                value: dateFormat.format(event.startDate!),
              ),
            if (event.endDate != null)
              _DetailRow(
                icon: AppIcons.calendar,
                label: 'End',
                value: dateFormat.format(event.endDate!),
              ),
            _DetailRow(
              icon: AppIcons.flag,
              label: 'Status',
              value: event.status.name,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.md,
      children: [
        Icon(
          icon,
          size: AppSizes.iconMd,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        Column(
          crossAxisAlignment: .start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}
