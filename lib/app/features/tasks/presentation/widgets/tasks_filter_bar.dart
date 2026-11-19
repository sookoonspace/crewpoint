/// `TasksFilterBar` — the search, filters, grouping and sort above the
/// Tasks list (Spec #186). Every control is keyed for journey tests:
/// the search field `tasks.list.search`, filter pills
/// `tasks.list.filterChip.<name>`, the crew pill `tasks.list.crewFilter`
/// (choices `tasks.list.crewFilter.<id>` and `.all`), the grouping
/// `tasks.list.groupToggle.<value>` and the sort button
/// `tasks.list.sortMenu` (choices `tasks.list.sortMenu.<key>`).
///
/// Stateless about the filter: it receives the current `filter` and one
/// `onFilterChanged` callback, and the caller keeps the state.
library;

import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/crew.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

class TasksFilterBar extends StatefulWidget {
  const TasksFilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    this.crews = const [],
    this.crewWords = (one: 'Crew', other: 'Crews'),
    this.readsBudgets = true,
  });

  final TasksFilter filter;
  final ValueChanged<TasksFilter> onFilterChanged;

  /// The event's crews (Req 72). With none, the crew filter and grouping
  /// are hidden.
  final List<CrewModel> crews;

  /// The event's words for a crew.
  final ({String one, String other}) crewWords;

  /// Whether the viewer may read budget figures (`budget.read`, Req 36).
  /// Without it the "Has budget" pill is hidden.
  final bool readsBudgets;

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
    if (!next.remove(status)) next.add(status);
    _emit(widget.filter.copyWith(statuses: next));
  }

  /// Back to every task, keeping the search, sort and grouping.
  void _all() {
    final f = widget.filter;
    _emit(TasksFilter(query: f.query, sortKey: f.sortKey, groupBy: f.groupBy));
  }

  Future<void> _pickCrew() async {
    final f = widget.filter;
    final strings = context.strings.crews;
    final picked = await showCpSheet<String>(
      context: context,
      title: widget.crewWords.one,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            CpListRow(
              key: const Key('tasks.list.crewFilter.all'),
              title: strings.allCrews(widget.crewWords.other),
              selected: f.crewId == null,
              trailing: f.crewId == null ? const _Tick() : const SizedBox(),
              onTap: () => Navigator.of(sheet).pop(''),
            ),
            for (final crew in widget.crews)
              CpListRow(
                key: Key('tasks.list.crewFilter.${crew.id}'),
                title: crew.name,
                selected: f.crewId == crew.id,
                trailing: f.crewId == crew.id
                    ? const _Tick()
                    : const SizedBox(),
                onTap: () => Navigator.of(sheet).pop(crew.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _emit(
      picked.isEmpty
          ? widget.filter.copyWith(clearCrewId: true)
          : widget.filter.copyWith(crewId: picked),
    );
  }

  Future<void> _pickSort() async {
    final s = context.strings.tasks;
    final current = widget.filter.sortKey;
    final picked = await showCpSheet<TasksSortKey>(
      context: context,
      title: s.sortBy,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final key in TasksSortKey.values)
              CpListRow(
                key: Key('tasks.list.sortMenu.${key.name}'),
                title: _sortLabel(s, key),
                selected: key == current,
                trailing: key == current ? const _Tick() : const SizedBox(),
                onTap: () => Navigator.of(sheet).pop(key),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _emit(widget.filter.copyWith(sortKey: picked));
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.tasks;
    final f = widget.filter;
    final crew = widget.crews.where((c) => c.id == f.crewId).firstOrNull;
    final anyFilter =
        f.statuses.isNotEmpty ||
        f.onlyMine ||
        f.onlyOverdue ||
        f.onlyWithBudget ||
        f.crewId != null;

    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final groupChoices = [
      CpChoice(
        TasksGroupBy.status,
        s.groupStatus,
        key: const Key('tasks.list.groupToggle.status'),
      ),
      CpChoice(
        TasksGroupBy.assignee,
        s.groupAssignee,
        key: const Key('tasks.list.groupToggle.assignee'),
      ),
      CpChoice(
        TasksGroupBy.dueWindow,
        s.groupDueWindow,
        key: const Key('tasks.list.groupToggle.dueWindow'),
      ),
      if (widget.crews.isNotEmpty)
        CpChoice(
          TasksGroupBy.crew,
          widget.crewWords.one,
          key: const Key('tasks.list.groupToggle.crew'),
        ),
    ];
    // With no crews, grouping by crew shows as status.
    final groupBy = widget.crews.isEmpty && f.groupBy == TasksGroupBy.crew
        ? TasksGroupBy.status
        : f.groupBy;
    final sort = IconButton(
      key: const Key('tasks.list.sortMenu'),
      tooltip: '${s.sortBy}: ${_sortLabel(s, f.sortKey)}',
      onPressed: _pickSort,
      icon: Icon(
        CpIcons.actionSort,
        size: cp.sizes.iconMd,
        color: cp.colors.text,
      ),
    );

    Widget pill(String name, String label, bool on, VoidCallback onTap) =>
        CpFilterChip(
          key: Key('tasks.list.filterChip.$name'),
          label: label,
          selected: on,
          onTap: onTap,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.sm,
      children: [
        // The key sits above the field, which tests find inside it.
        KeyedSubtree(
          key: const Key('tasks.list.search'),
          child: CpSearchField(
            hint: s.searchHint,
            controller: _searchController,
            onChanged: (v) => _emit(f.copyWith(query: v)),
          ),
        ),
        SingleChildScrollView(
          key: const Key('tasks.list.filters'),
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: cp.space.sm,
            children: [
              pill('all', s.filterAll, !anyFilter, _all),
              pill(
                'mine',
                s.filterChipMine,
                f.onlyMine,
                () => _emit(f.copyWith(onlyMine: !f.onlyMine)),
              ),
              pill(
                'overdue',
                s.filterChipOverdue,
                f.onlyOverdue,
                () => _emit(f.copyWith(onlyOverdue: !f.onlyOverdue)),
              ),
              if (widget.crews.isNotEmpty)
                CpFilterChip(
                  key: const Key('tasks.list.crewFilter'),
                  label: crew?.name ?? widget.crewWords.one,
                  selected: crew != null,
                  menu: true,
                  onTap: _pickCrew,
                ),
              if (widget.readsBudgets)
                pill(
                  'hasBudget',
                  s.filterChipHasBudget,
                  f.onlyWithBudget,
                  () => _emit(f.copyWith(onlyWithBudget: !f.onlyWithBudget)),
                ),
              pill(
                'todo',
                s.statusTodo,
                f.statuses.contains(TaskStatus.todo),
                () => _toggleStatus(TaskStatus.todo),
              ),
              pill(
                'inProgress',
                s.statusInProgress,
                f.statuses.contains(TaskStatus.inProgress),
                () => _toggleStatus(TaskStatus.inProgress),
              ),
              pill(
                'done',
                s.statusDone,
                f.statuses.contains(TaskStatus.done),
                () => _toggleStatus(TaskStatus.done),
              ),
            ],
          ),
        ),
        // Side by side normally; at large text the choices wrap as pills
        // so no label breaks mid-word (Req 45).
        if (large)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CpChoiceChips<TasksGroupBy>(
                  key: const Key('tasks.list.groupToggle'),
                  label: s.groupBy,
                  choices: groupChoices,
                  selected: {groupBy},
                  onChanged: (g) {
                    if (g.isNotEmpty) _emit(f.copyWith(groupBy: g.first));
                  },
                ),
              ),
              sort,
            ],
          )
        else
          Row(
            spacing: cp.space.sm,
            children: [
              Expanded(
                child: CpSegmented<TasksGroupBy>(
                  key: const Key('tasks.list.groupToggle'),
                  semanticLabel: s.groupBy,
                  choices: groupChoices,
                  selected: groupBy,
                  onChanged: (g) => _emit(f.copyWith(groupBy: g)),
                ),
              ),
              sort,
            ],
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

/// The tick on the chosen row of a sheet.
class _Tick extends StatelessWidget {
  const _Tick();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Icon(CpIcons.check, size: cp.sizes.iconMd, color: cp.colors.accent);
  }
}
