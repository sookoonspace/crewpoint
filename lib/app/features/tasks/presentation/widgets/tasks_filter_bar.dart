/// `TasksFilterBar` — the Tasks-screen control surface above the list.
///
/// Renders four interactive zones, all keyed for journey tests:
/// 1. A search row keyed `tasks.list.search` that emits filter.query
///    changes on every keystroke.
/// 2. A `Wrap` of `FilterChip`s for status (todo / inProgress / done)
///    plus "Mine", "Overdue", and "Has budget" predicate chips.
/// 3. A sort `PopupMenuButton<TasksSortKey>` keyed `tasks.list.sortMenu`
///    with items keyed `tasks.list.sortMenu.<key>`.
/// 4. A `SegmentedButton<TasksGroupBy>` for the group toggle, each
///    segment keyed `tasks.list.groupToggle.<value>`.
///
/// Stateless: receives the current `filter` and a single
/// `onFilterChanged` callback. The parent (`EventTasksPage`) owns the
/// session-only state.
library;

import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/reserved_checkmark_chip.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

class TasksFilterBar extends StatefulWidget {
  const TasksFilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
  });

  final TasksFilter filter;
  final ValueChanged<TasksFilter> onFilterChanged;

  @override
  State<TasksFilterBar> createState() => _TasksFilterBarState();
}

class _TasksFilterBarState extends State<TasksFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filter.query);
  }

  @override
  void didUpdateWidget(TasksFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter.query != _searchController.text) {
      _searchController.text = widget.filter.query;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _emit(TasksFilter next) => widget.onFilterChanged(next);

  void _toggleStatus(TaskStatus status) {
    final next = {...widget.filter.statuses};
    if (next.contains(status)) {
      next.remove(status);
    } else {
      next.add(status);
    }
    _emit(widget.filter.copyWith(statuses: next));
  }

  /// Width-locks the SegmentedButton's three group-by segments so the
  /// Material `showSelectedIcon` (✓) doesn't grow the selected segment
  /// and shrink the others (2026-06-11 iPhone 12 mini QA). Measures the
  /// widest of the three labels at the SegmentedButton's text style
  /// (`labelLarge`) and adds the standard reserved-icon slot width
  /// (= `IconTheme.iconSize` 18 + `AppSpacing.xs` 4 = 22) so the ✓
  /// fits inside the shared slot.
  double _groupSegmentSlotWidth(BuildContext context, TasksStrings s) {
    final style = Theme.of(context).textTheme.labelLarge;
    double measure(String text) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      return tp.width;
    }

    final widest = [
      measure(s.groupStatus),
      measure(s.groupAssignee),
      measure(s.groupDueWindow),
    ].reduce((a, b) => a > b ? a : b);
    return widest + 22.0;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.tasks;
    final f = widget.filter;
    final groupSlotWidth = _groupSegmentSlotWidth(context, s);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Search row.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          // KeyedSubtree carries the row-level key; widget tests assert
          // the TextField as a descendant for stable lookup.
          child: KeyedSubtree(
            key: const Key('tasks.list.search'),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => _emit(f.copyWith(query: v)),
              decoration: InputDecoration(
                hintText: s.searchHint,
                prefixIcon: const Icon(AppIcons.actionSearch),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
        ),

        // 2. Filter chips (predicate + per-status).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: [
              ReservedCheckmarkChip(
                key: const Key('tasks.list.filterChip.mine'),
                label: s.filterChipMine,
                selected: f.onlyMine,
                onChanged: (sel) => _emit(f.copyWith(onlyMine: sel)),
                selectedColor: AppColors.sage.withValues(alpha: 0.25),
              ),
              ReservedCheckmarkChip(
                key: const Key('tasks.list.filterChip.overdue'),
                label: s.filterChipOverdue,
                selected: f.onlyOverdue,
                onChanged: (sel) => _emit(f.copyWith(onlyOverdue: sel)),
                selectedColor: AppColors.terracotta.withValues(alpha: 0.25),
              ),
              ReservedCheckmarkChip(
                key: const Key('tasks.list.filterChip.hasBudget'),
                label: s.filterChipHasBudget,
                selected: f.onlyWithBudget,
                onChanged: (sel) => _emit(f.copyWith(onlyWithBudget: sel)),
                selectedColor: AppColors.sage.withValues(alpha: 0.25),
              ),
              ReservedCheckmarkChip(
                key: const Key('tasks.list.filterChip.todo'),
                label: s.statusTodo,
                selected: f.statuses.contains(TaskStatus.todo),
                onChanged: (_) => _toggleStatus(TaskStatus.todo),
                selectedColor: AppColors.sage.withValues(alpha: 0.25),
              ),
              ReservedCheckmarkChip(
                key: const Key('tasks.list.filterChip.inProgress'),
                label: s.statusInProgress,
                selected: f.statuses.contains(TaskStatus.inProgress),
                onChanged: (_) => _toggleStatus(TaskStatus.inProgress),
                selectedColor: AppColors.sage.withValues(alpha: 0.25),
              ),
              ReservedCheckmarkChip(
                key: const Key('tasks.list.filterChip.done'),
                label: s.statusDone,
                selected: f.statuses.contains(TaskStatus.done),
                onChanged: (_) => _toggleStatus(TaskStatus.done),
                selectedColor: AppColors.sage.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // 3. Sort menu + 4. Group toggle row. Wrap so the segmented button
        // drops to a new line on narrow viewports instead of overflowing.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              PopupMenuButton<TasksSortKey>(
                key: const Key('tasks.list.sortMenu'),
                initialValue: f.sortKey,
                onSelected: (key) => _emit(f.copyWith(sortKey: key)),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    key: const Key('tasks.list.sortMenu.dueDate'),
                    value: TasksSortKey.dueDate,
                    child: Text(s.sortDueDate),
                  ),
                  PopupMenuItem(
                    key: const Key('tasks.list.sortMenu.priority'),
                    value: TasksSortKey.priority,
                    child: Text(s.sortPriority),
                  ),
                  PopupMenuItem(
                    key: const Key('tasks.list.sortMenu.created'),
                    value: TasksSortKey.created,
                    child: Text(s.sortCreated),
                  ),
                  PopupMenuItem(
                    key: const Key('tasks.list.sortMenu.title'),
                    value: TasksSortKey.title,
                    child: Text(s.sortTitle),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.actionSort,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${s.sortBy}: ${_sortLabel(s, f.sortKey)}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              SegmentedButton<TasksGroupBy>(
                key: const Key('tasks.list.groupToggle'),
                // showSelectedIcon: false disables Material's auto-✓
                // (which grows the selected segment). We render our own
                // reserved-✓ slot inside each label, so every segment
                // has identical intrinsic width regardless of selection.
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: TasksGroupBy.status,
                    label: _GroupSegmentLabel(
                      key: const Key('tasks.list.groupToggle.status'),
                      label: s.groupStatus,
                      selected: f.groupBy == TasksGroupBy.status,
                      width: groupSlotWidth,
                    ),
                  ),
                  ButtonSegment(
                    value: TasksGroupBy.assignee,
                    label: _GroupSegmentLabel(
                      key: const Key('tasks.list.groupToggle.assignee'),
                      label: s.groupAssignee,
                      selected: f.groupBy == TasksGroupBy.assignee,
                      width: groupSlotWidth,
                    ),
                  ),
                  ButtonSegment(
                    value: TasksGroupBy.dueWindow,
                    label: _GroupSegmentLabel(
                      key: const Key('tasks.list.groupToggle.dueWindow'),
                      label: s.groupDueWindow,
                      selected: f.groupBy == TasksGroupBy.dueWindow,
                      width: groupSlotWidth,
                    ),
                  ),
                ],
                selected: {f.groupBy},
                onSelectionChanged: (set) =>
                    _emit(f.copyWith(groupBy: set.first)),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _sortLabel(TasksStrings s, TasksSortKey key) => switch (key) {
    TasksSortKey.dueDate => s.sortDueDate,
    TasksSortKey.priority => s.sortPriority,
    TasksSortKey.created => s.sortCreated,
    TasksSortKey.title => s.sortTitle,
  };
}

/// SegmentedButton group-toggle label with a reserved-✓ leading slot so
/// segment widths stay constant across selection. Material's default
/// `showSelectedIcon: true` grows the selected segment to fit the ✓;
/// disabling it (in the parent `SegmentedButton`) + rendering our own
/// `Visibility(maintainSize)` ✓ here keeps the intrinsic width identical
/// for every segment regardless of which one is selected.
class _GroupSegmentLabel extends StatelessWidget {
  const _GroupSegmentLabel({
    super.key,
    required this.label,
    required this.selected,
    required this.width,
  });

  final String label;
  final bool selected;
  final double width;

  static const double _reservedSlotWidth = 22.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _reservedSlotWidth,
            child: Visibility(
              visible: selected,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: const Icon(Icons.check, size: 18),
            ),
          ),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
