import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/progress_ring.dart';
import 'package:crewpoint_app/app/core/widgets/status_badge.dart';

/// Combined progress ring + status-count chips. The default `compact` form
/// (ring only) lives on `EventTile`; the full form (ring + 3 chips) is used
/// at the top of `MyTasksScreen` and on rail-width Dashboard layouts.
class TaskProgressSummary extends StatelessWidget {
  const TaskProgressSummary({
    super.key,
    required this.todo,
    required this.doing,
    required this.done,
    this.compact = false,
    this.ringSize = 48,
  });

  final int todo;
  final int doing;
  final int done;
  final bool compact;
  final double ringSize;

  @override
  Widget build(BuildContext context) {
    final ring = ProgressRing(
      todo: todo,
      doing: doing,
      done: done,
      size: ringSize,
    );
    if (compact) return ring;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ring,
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge.todo(label: 'To do', count: todo),
              StatusBadge.doing(label: 'Doing', count: doing),
              StatusBadge.done(label: 'Done', count: done),
            ],
          ),
        ),
      ],
    );
  }
}
