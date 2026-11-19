import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// A group's title above its card of tasks, such as "Overdue" with "2",
/// shared by the event's Tasks list and My tasks.
class TasksGroupHeader extends StatelessWidget {
  const TasksGroupHeader({super.key, required this.label, this.count});

  final String label;

  /// How many tasks the group holds, shown quietly on the right.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Padding(
      padding: EdgeInsets.only(top: cp.space.lg, bottom: cp.space.sm),
      child: CpSectionHeader(title: label, trailingText: count?.toString()),
    );
  }
}
