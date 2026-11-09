import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/data/participant_repository.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:crewpoint_app/app/features/participants/presentation/group_sheets.dart';

/// Who is attending (Req 43, route `people`). With `participants.read` it
/// pages through everyone, searching by name and filtering by group. A
/// linked adult without it sees only their own groups. Anyone else sees a
/// no-access message. The list is read online and never kept on the device.
class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  GroupModel? _group;
  EventCategory? _category;

  /// A field answer to filter by, such as Diet is Jain.
  ({CustomField field, Object value})? _answer;
  RosterQuery? _started;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  RosterController get _controller =>
      ref.read(rosterProvider(widget.event.id).notifier);

  /// Starts [query] once the frame is built, and again only when it changes.
  void _ensureStarted(RosterQuery query) {
    if (_started == query) return;
    _started = query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.start(query));
    });
  }

  RosterQuery _query(List<String>? ownGroups) => RosterQuery(
    search: _search.text,
    groupId: ownGroups == null ? _group?.id : null,
    categoryId: ownGroups == null ? _category?.id : null,
    tag: ownGroups == null && _answer != null
        ? filterTag(_answer!.field.id, _answer!.value)
        : null,
    groupIds: ownGroups?.take(30).toList(),
  );

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => setState(() {}));
  }

  Future<void> _pickGroup() async {
    final picked = await GroupPickerSheet.show(
      context,
      event: widget.event,
      allowCreate: false,
    );
    if (picked != null && mounted) setState(() => _group = picked);
  }

  /// Picks a standard choice or yes/no field, then one of its answers.
  Future<void> _pickAnswer(List<CustomField> fields) async {
    final strings = context.strings.fields;
    final picked =
        await showModalBottomSheet<({CustomField field, Object value})>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (sheet) => ListView(
            key: const Key('people.roster.answerPicker'),
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final f in fields) ...[
                Text(f.label, style: Theme.of(sheet).textTheme.titleSmall),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final Object v
                        in f.type == FieldType.yesNo
                            ? const [true, false]
                            : f.options)
                      ActionChip(
                        key: Key('people.roster.answer.${filterTag(f.id, v)}'),
                        label: Text(
                          v is bool ? (v ? strings.yes : strings.no) : '$v',
                        ),
                        onPressed: () =>
                            Navigator.of(sheet).pop((field: f, value: v)),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        );
    if (picked != null && mounted) setState(() => _answer = picked);
  }

  Future<void> _manageGroup(GroupModel group) async {
    final result = await GroupSheet.show(
      context,
      event: widget.event,
      group: group,
    );
    if (!mounted) return;
    setState(() {
      _group = switch (result) {
        GroupSheetResult(deleted: true) => null,
        GroupSheetResult(:final group?) => group,
        _ => _group,
      };
      _started = null;
    });
  }

  void _open(String participantId) => context.push(
    '/dashboard/event/${widget.event.id}/people/$participantId'
    '${participantId == 'new' && _group != null ? '?group=${_group!.id}' : ''}',
  );

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final words = event.words;
    final strings = context.strings.people;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final browses = event.can(me, 'participants.read');
    final edits = event.can(me, 'participants.edit');

    Widget scaffold(Widget body, {Widget? fab}) => Scaffold(
      appBar: AppBar(title: Text(words.other('participant')), elevation: 0),
      floatingActionButton: fab,
      body: body,
    );

    List<String>? ownGroups;
    if (!browses) {
      final mine = ref.watch(myMemberProvider(event.id));
      if (!mine.hasValue && mine.isLoading) {
        return scaffold(
          const Center(
            child: CircularProgressIndicator(key: Key('people.roster.loading')),
          ),
        );
      }
      ownGroups = mine.value?.groupIds ?? const [];
      if (ownGroups.isEmpty) return scaffold(const NoAccessView());
    }

    final query = _query(ownGroups);
    _ensureStarted(query);
    final roster = ref.watch(rosterProvider(event.id));
    final categories = categoriesOf(event.settings);
    final categoryNames = {for (final c in categories) c.id: c.name};
    final filterFields = [
      for (final f
          in ref.watch(eventFieldsProvider(event.id)).value ??
              const <CustomField>[])
        if (f.filters && f.scope == FieldScope.participant) f,
    ];
    final fieldStrings = context.strings.fields;
    final hasGroupFields =
        (ref.watch(eventFieldsProvider(event.id)).value ??
                const <CustomField>[])
            .any((f) => f.scope == FieldScope.group);
    final ownGroupNames = ownGroups == null || !hasGroupFields
        ? const <String, GroupModel>{}
        : ref
                  .watch(
                    groupsByIdProvider((
                      eventId: event.id,
                      ids: ownGroups.join(','),
                    )),
                  )
                  .value ??
              const <String, GroupModel>{};
    final canAdd =
        (edits || ownGroups != null) && event.status != EventStatus.archived;

    final header = <Widget>[
      TextField(
        key: const Key('people.roster.search'),
        controller: _search,
        onChanged: _onSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(AppIcons.actionSearch),
          hintText: strings.searchHint(words.other('participant')),
          border: const OutlineInputBorder(),
        ),
      ),
      if (browses)
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_group == null)
              OutlinedButton.icon(
                key: const Key('people.roster.groupFilter'),
                onPressed: _pickGroup,
                icon: const Icon(AppIcons.filter),
                label: Text(strings.filterByGroup(words.one('group'))),
              )
            else ...[
              InputChip(
                key: const Key('people.roster.groupChip'),
                label: Text(_group!.name),
                onPressed: _pickGroup,
                onDeleted: () => setState(() => _group = null),
                deleteButtonTooltipMessage: strings.clearGroup(
                  words.one('group'),
                ),
              ),
              if (edits)
                TextButton(
                  key: const Key('people.roster.groupManage'),
                  onPressed: () => _manageGroup(_group!),
                  child: Text(strings.manageGroup(words.one('group'))),
                ),
            ],
            if (categories.isNotEmpty)
              if (_category == null)
                PopupMenuButton<EventCategory>(
                  key: const Key('people.roster.categoryFilter'),
                  tooltip: fieldStrings.filterByCategory(words.one('category')),
                  onSelected: (c) => setState(() => _category = c),
                  itemBuilder: (_) => [
                    for (final c in categories)
                      PopupMenuItem(
                        key: Key('people.roster.category.${c.id}'),
                        value: c,
                        child: Text(c.name),
                      ),
                  ],
                  child: Chip(
                    avatar: const Icon(AppIcons.filter, size: 18),
                    label: Text(
                      fieldStrings.filterByCategory(words.one('category')),
                    ),
                  ),
                )
              else
                InputChip(
                  key: const Key('people.roster.categoryChip'),
                  label: Text(_category!.name),
                  onDeleted: () => setState(() => _category = null),
                ),
            if (filterFields.isNotEmpty)
              if (_answer == null)
                ActionChip(
                  key: const Key('people.roster.fieldFilter'),
                  avatar: const Icon(AppIcons.filter, size: 18),
                  label: Text(
                    fieldStrings.filterByField(words.one('customField')),
                  ),
                  onPressed: () => _pickAnswer(filterFields),
                )
              else
                InputChip(
                  key: const Key('people.roster.fieldChip'),
                  label: Text(
                    '${_answer!.field.label}: ${_answer!.value is bool ? ((_answer!.value as bool) ? fieldStrings.yes : fieldStrings.no) : _answer!.value}',
                  ),
                  onDeleted: () => setState(() => _answer = null),
                ),
          ],
        ),
      // A linked adult answers their own group's questions (Req 41).
      for (final g in ownGroupNames.values)
        OutlinedButton.icon(
          key: Key('people.roster.ownGroup.${g.id}'),
          onPressed: () =>
              GroupSheet.show(context, event: event, group: g, manage: false),
          icon: const Icon(AppIcons.members),
          label: Text(g.name),
        ),
      Text(
        strings.onlineNote,
        key: const Key('people.roster.online'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];

    final Widget list;
    if (!roster.started || (roster.loading && roster.items.isEmpty)) {
      list = const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: CircularProgressIndicator(key: Key('people.roster.loading')),
        ),
      );
    } else if (roster.error != null && roster.items.isEmpty) {
      list = _Failed(onRetry: _controller.loadMore);
    } else if (roster.items.isEmpty) {
      list = Column(
        key: const Key('people.roster.empty'),
        children: [
          Text(
            strings.emptyTitle(words.other('participant')),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            strings.emptyHint(words.one('group')),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      list = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in roster.items)
            _PersonTile(
              person: p,
              groupName: [
                if (p.groupId != null) ?roster.groups[p.groupId]?.name,
                // The age band, never a birth date (Z-01).
                if (p.categoryId != null) ?categoryNames[p.categoryId],
              ].join(' · '),
              onTap: () => _open(p.id),
            ),
          if (roster.error != null)
            _Failed(onRetry: _controller.loadMore)
          else if (roster.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Center(
                child: roster.loading
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        key: const Key('people.roster.more'),
                        onPressed: _controller.loadMore,
                        child: Text(strings.loadMore),
                      ),
              ),
            ),
        ],
      );
    }

    return scaffold(
      RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView(
          key: const Key('people.roster.list'),
          padding: EdgeInsets.fromLTRB(
            Breakpoints.screenHorizontalPadding(context),
            AppSpacing.lg,
            Breakpoints.screenHorizontalPadding(context),
            AppSpacing.xxxl + AppSpacing.xl,
          ),
          children: [
            ContentMaxWidth(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.md,
                children: [...header, list],
              ),
            ),
          ],
        ),
      ),
      fab: canAdd
          ? FloatingActionButton.extended(
              key: const Key('people.roster.add'),
              onPressed: () => _open('new'),
              icon: const Icon(AppIcons.actionAdd),
              label: Text(strings.add(words.one('participant'))),
            )
          : null,
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    this.groupName,
    required this.onTap,
  });

  final ParticipantModel person;
  final String? groupName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.people;
    final theme = Theme.of(context);
    return ListTile(
      key: Key('people.tile.${person.id}'),
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: AppSpacing.md,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        child: Text(person.name.isEmpty ? '?' : person.name.characters.first),
      ),
      title: Text(person.name),
      subtitle: (groupName ?? '').isEmpty ? null : Text(groupName!),
      trailing: person.isChild
          ? Chip(
              key: Key('people.tile.${person.id}.child'),
              label: Text(strings.child),
              visualDensity: VisualDensity.compact,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.people;
    final theme = Theme.of(context);
    return Column(
      key: const Key('people.roster.error'),
      children: [
        Text(
          strings.loadFailed,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        TextButton.icon(
          key: const Key('people.roster.retry'),
          onPressed: onRetry,
          icon: const Icon(AppIcons.actionRetry),
          label: Text(strings.retry),
        ),
      ],
    );
  }
}
