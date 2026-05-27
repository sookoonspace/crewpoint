import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_sizes.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/task_progress_summary.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/event_type_emoji.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Dashboard event card. Stateless and parameter-driven — the host widget
/// (`event_card.dart`) watches `eventTaskCountsProvider` and threads the
/// counts in here.
class EventTile extends StatelessWidget {
  const EventTile({
    super.key,
    required this.event,
    required this.todo,
    required this.doing,
    required this.done,
    this.onTap,
  });

  final EventModel event;
  final int todo;
  final int doing;
  final int done;
  final VoidCallback? onTap;

  String _dateRange() {
    final start = event.startDate;
    final end = event.endDate;
    if (start == null) return '';
    final fmt = DateFormat.MMMd();
    if (end == null || end == start) return fmt.format(start);
    return '${fmt.format(start)}–${fmt.format(end)}';
  }

  String _memberCount() {
    final n = event.memberIds.length;
    return n == 1 ? '1 member' : '$n members';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('event.tile.${event.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                iconForEventType(event.eventType),
                size: AppSizes.emojiTile,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_dateRange().isNotEmpty)
                      Text(
                        _dateRange(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      _memberCount(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              KeyedSubtree(
                key: Key('event.tile.${event.id}.ring'),
                child: TaskProgressSummary(
                  todo: todo,
                  doing: doing,
                  done: done,
                  compact: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
