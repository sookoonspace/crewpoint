import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/layout/breakpoints.dart';
import 'package:crewpoint_app/app/core/design/layout/cp_list_detail.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_filters.dart';
import 'package:crewpoint_app/app/features/registration/application/waivers_provider.dart';
import 'package:crewpoint_app/app/features/registration/presentation/widgets/registration_status.dart';
import 'package:crewpoint_app/app/features/participants/data/participant_repository.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:crewpoint_app/app/features/participants/presentation/group_entry_screen.dart';
import 'package:crewpoint_app/app/features/participants/presentation/group_sheets.dart';

/// Who is attending (Req 43, route `people`). With `participants.read` it
/// pages through everyone, searching by name and filtering by group. A
/// linked adult without it sees only their own groups. Anyone else sees a
/// no-access message. The list is read online and never kept on the device.
///
/// From 840 px it is a list and detail (Spec #186 Req 23): the route
/// `people/:participantId` builds this with [selectedId] and that person's
/// record as [detail], beside the list. Narrower, the record is a page of
/// its own.
class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({
    super.key,
    required this.event,
    this.selectedId,
    this.detail,
  });

  final EventModel event;

  /// The person shown beside the list, from the route.
  final String? selectedId;
  final Widget? detail;

  @override
  ConsumerState<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  late final TextEditingController _search;
  late final ScrollController _scroll;
  Timer? _debounce;
  RosterQuery? _started;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(rosterFiltersProvider(widget.event.id)).search,
    );
    _scroll = ScrollController(
      initialScrollOffset: _filtersController.scrollOffset,
    );
    _scroll.addListener(() {
      if (mounted && _scroll.hasClients) {
        _filtersController.scrollOffset = _scroll.offset;
      }
    });
  }

  /// Read fresh each time, never in dispose: the provider is rebuilt when
  /// no roster has watched it for a while.
  RosterFiltersController get _filtersController =>
      ref.read(rosterFiltersProvider(widget.event.id).notifier);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  RosterController get _controller =>
      ref.read(rosterProvider(widget.event.id).notifier);

  /// Starts [query] once the frame is built, and again only when it changes.
  /// A list built again for a chosen person keeps the pages already loaded.
  void _ensureStarted(RosterQuery query) {
    if (_started == query) return;
    _started = query;
    final current = ref.read(rosterProvider(widget.event.id));
    if (current.started && current.query == query) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.start(query));
    });
  }

  RosterQuery _query(RosterFilters f, List<String>? ownGroups) => RosterQuery(
    search: f.search,
    groupId: ownGroups == null ? f.group?.id : null,
    categoryId: ownGroups == null ? f.category?.id : null,
    tag: ownGroups == null && f.answer != null
        ? filterTag(f.answer!.field.id, f.answer!.value)
        : null,
    groupIds: ownGroups?.take(30).toList(),
    missingWaiver: ownGroups == null && f.missingWaiver,
    registrationStatus: ownGroups == null ? f.registrationStatus : null,
  );

  /// Picks a registration status to list (#249). Drafts have no people.
  Future<void> _pickStatus() async {
    final s = context.strings.committee;
    final picked = await showCpSheet<String>(
      context: context,
      title: s.statusFilter,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final status in const [
              'submitted',
              'pending',
              'waitlisted',
              'cancelled',
            ])
              CpListRow(
                key: Key('people.roster.status.$status'),
                leading: RegistrationStatusIcon(status: status),
                title: s.status(status),
                onTap: () => Navigator.of(sheet).pop(status),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      _filtersController.setRegistrationStatus(picked);
    }
  }

  /// Emails each registration with someone missing a waiver (#246, W-05),
  /// after a confirm.
  Future<void> _sendReminders() async {
    final strings = context.strings.people;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => CpDialog(
        title: strings.remindersTitle,
        message: strings.remindersBody,
        actions: [
          CpButton.text(
            key: const Key('people.roster.reminders.cancel'),
            label: MaterialLocalizations.of(dialog).cancelButtonLabel,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          CpButton(
            key: const Key('people.roster.reminders.confirm'),
            label: strings.send,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final sent = await ref
          .read(memberCallsProvider)
          .sendWaiverReminders(widget.event.id);
      messenger.showSnackBar(
        SnackBar(content: Text(strings.remindersSent(sent))),
      );
    } on Object catch (e, st) {
      log('sendWaiverReminders failed', error: e, stackTrace: st);
      messenger.showSnackBar(
        SnackBar(content: Text(strings.remindersFailed)),
      );
    }
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _filtersController.setSearch(text),
    );
  }

  Future<void> _pickGroup() async {
    final picked = await GroupPickerSheet.show(
      context,
      event: widget.event,
      allowCreate: false,
    );
    if (picked != null && mounted) _filtersController.setGroup(picked);
  }

  Future<void> _pickCategory(List<EventCategory> categories) async {
    final picked = await showCpSheet<EventCategory>(
      context: context,
      title: context.strings.fields.filterByCategory(
        widget.event.words.one('category'),
      ),
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final c in categories)
              CpListRow(
                key: Key('people.roster.category.${c.id}'),
                title: c.name,
                onTap: () => Navigator.of(sheet).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) _filtersController.setCategory(picked);
  }

  /// Picks a standard choice or yes/no field, then one of its answers.
  Future<void> _pickAnswer(List<CustomField> fields) async {
    final strings = context.strings.fields;
    final picked = await showCpSheet<({CustomField field, Object value})>(
      context: context,
      title: strings.filterByField(widget.event.words.one('customField')),
      builder: (sheet) {
        final cp = sheet.cp;
        return Column(
          key: const Key('people.roster.answerPicker'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: cp.space.md,
          children: [
            for (final f in fields)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: cp.space.xs,
                children: [
                  Text(
                    f.label,
                    style: cp.type.titleSmall.copyWith(color: cp.colors.text),
                  ),
                  Wrap(
                    spacing: cp.space.sm,
                    children: [
                      for (final Object v
                          in f.type == FieldType.yesNo
                              ? const [true, false]
                              : f.options)
                        CpFilterChip(
                          key: Key(
                            'people.roster.answer.${filterTag(f.id, v)}',
                          ),
                          label: v is bool
                              ? (v ? strings.yes : strings.no)
                              : '$v',
                          onTap: () =>
                              Navigator.of(sheet).pop((field: f, value: v)),
                        ),
                    ],
                  ),
                ],
              ),
          ],
        );
      },
    );
    if (picked != null && mounted) _filtersController.setAnswer(picked);
  }

  Future<void> _manageGroup(GroupModel group) async {
    final result = await GroupSheet.show(
      context,
      event: widget.event,
      group: group,
    );
    if (!mounted) return;
    if (result case GroupSheetResult(addPeople: true, :final group?)) {
      await _openGroupEntry(group: group);
      return;
    }
    if (result case GroupSheetResult(editAnswers: true, :final group?)) {
      await _openGroupEntry(group: group, editing: true);
      return;
    }
    if (result case GroupSheetResult(seeRegistration: true, :final group?)) {
      await context.push(
        '/dashboard/event/${widget.event.id}/people/registration/${group.id}',
      );
      return;
    }
    switch (result) {
      case GroupSheetResult(deleted: true):
        _filtersController.setGroup(null);
      case GroupSheetResult(:final group?):
        _filtersController.setGroup(group);
      default:
    }
    setState(() => _started = null);
    unawaited(_controller.refresh());
  }

  /// The group screen (Spec #186 Req 26): a new group, or more people for
  /// [group]. Afterwards People shows that group (Req 35).
  Future<void> _openGroupEntry({
    GroupModel? group,
    bool editing = false,
  }) async {
    final result = await context.push<GroupEntryResult>(
      '/dashboard/event/${widget.event.id}/people/group-entry'
      '${group == null ? '' : '?group=${group.id}'}'
      '${group != null && editing ? '&mode=edit' : ''}',
    );
    if (result == null || !mounted) return;
    _filtersController.setGroup(result.group);
    setState(() => _started = null);
    unawaited(_controller.refresh());
  }

  /// "+" for someone who may add anyone: one person or a whole group.
  Future<void> _chooseAdd() async {
    final words = widget.event.words;
    final strings = context.strings.groupEntry;
    final choice = await showCpSheet<String>(
      context: context,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            CpListRow(
              key: const Key('people.roster.addPerson'),
              leading: const Icon(CpIcons.memberAdd),
              title: strings.addPerson(words.one('participant')),
              onTap: () => Navigator.of(sheet).pop('person'),
            ),
            CpListRow(
              key: const Key('people.roster.addGroup'),
              leading: const Icon(CpIcons.members),
              title: strings.addGroup(words.one('group')),
              onTap: () => Navigator.of(sheet).pop('group'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'person':
        _open('new');
      case 'group':
        await _openGroupEntry();
    }
  }

  /// Opens a person's record: beside the list from 840 px, so the route
  /// changes in place; narrower, as a page of its own.
  void _open(String participantId) {
    final group = ref.read(rosterFiltersProvider(widget.event.id)).group;
    final path =
        '/dashboard/event/${widget.event.id}/people/$participantId'
        '${participantId == 'new' && group != null ? '?group=${group.id}' : ''}';
    if (CpListDetail.isSplit(context)) {
      context.go(path);
    } else {
      context.push(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final words = event.words;
    final detail = widget.detail;
    // Keeps the filters while this list is up, even before it shows.
    ref.watch(rosterFiltersProvider(event.id));
    // Narrower than 840 px a chosen person is a page of their own.
    if (detail != null && !CpListDetail.isSplit(context)) return detail;

    final me = ref.watch(currentUserIdProvider) ?? '';
    final browses = event.can(me, 'participants.read');
    final edits = event.can(me, 'participants.edit');
    final roles = context.strings.roles;

    List<String>? ownGroups;
    Widget? body;
    if (!browses) {
      final mine = ref.watch(myMemberProvider(event.id));
      if (!mine.hasValue && mine.isLoading) {
        body = KeyedSubtree(
          key: const Key('people.roster.loading'),
          child: CpLoadingState(semanticLabel: words.other('participant')),
        );
      } else {
        ownGroups = mine.value?.groupIds ?? const [];
        final ownRecord = mine.value?.participantId;
        if (ownGroups.isEmpty) {
          // Linked without a group (Req 46): their own record, nobody
          // else's.
          body = ownRecord == null
              ? const NoAccessView()
              : _OwnRecord(
                  eventId: event.id,
                  participantId: ownRecord,
                  selected: widget.selectedId == ownRecord,
                  onTap: () => _open(ownRecord),
                );
        }
      }
    }
    final canAdd =
        body == null &&
        (edits || ownGroups != null) &&
        event.status != EventStatus.archived;

    final list =
        body ?? _list(context, ownGroups, browses: browses, edits: edits);
    return Scaffold(
      appBar: CpTopBar(
        title: words.other('participant'),
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        leadingKey: const Key('people.roster.back'),
        onLeading: () => context.canPop()
            ? context.pop()
            : context.go('/dashboard/event/${event.id}'),
        actions: [
          if (event.can(me, 'participants.import'))
            CpTopBarAction(
              key: const Key('people.roster.import'),
              tooltip: context.strings.imports.rosterAction,
              icon: CpIcons.importFile,
              onPressed: () =>
                  context.push('/dashboard/event/${event.id}/people/import'),
            ),
          if (canAdd)
            CpTopBarAction(
              key: const Key('people.roster.add'),
              tooltip: context.strings.people.add(words.one('participant')),
              icon: CpIcons.actionAdd,
              primary: true,
              // Anyone who may add anyone chooses a person or a whole group;
              // a linked adult adds to their own group.
              onPressed: edits ? _chooseAdd : () => _open('new'),
            ),
        ],
      ),
      body: CpListDetail(
        list: list,
        detail: detail,
        placeholder: context.strings.nav.selectToSee(words.one('participant')),
        unsavedText: CpUnsavedText(
          title: roles.discardTitle,
          body: roles.discardBody,
          keep: roles.keepEditing,
          discard: roles.discard,
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<String>? ownGroups, {
    required bool browses,
    required bool edits,
  }) {
    final cp = context.cp;
    final event = widget.event;
    final words = event.words;
    final strings = context.strings.people;
    final fieldStrings = context.strings.fields;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final filters = ref.watch(rosterFiltersProvider(event.id));
    // The other copy of the list (beside a chosen person) may have searched.
    ref.listen(rosterFiltersProvider(event.id).select((f) => f.search), (
      _,
      next,
    ) {
      if (_search.text != next) _search.text = next;
    });

    final waiting = edits && event.can(me, 'participants.readPrivate')
        ? ref.watch(linkRequestsProvider(event.id)).value?.length ?? 0
        : 0;
    final query = _query(filters, ownGroups);
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
    final ownGroupNames = ownGroups == null
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
    // The whole roster's size, only when nothing narrows it.
    final total = browses && !filters.any
        ? ref.watch(participantCountProvider(event.id)).value
        : null;
    final answer = filters.answer;
    final hasWaivers =
        browses &&
        (ref.watch(eventWaiversProvider(event.id)).value?.isNotEmpty ?? false);

    final header = <Widget>[
      CpSearchField(
        fieldKey: const Key('people.roster.search'),
        controller: _search,
        onChanged: _onSearch,
        hint: strings.searchHint(words.other('participant')),
      ),
      if (browses)
        Wrap(
          spacing: cp.space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CpFilterChip(
              key: const Key('people.roster.all'),
              label: strings.all,
              selected:
                  filters.group == null &&
                  filters.category == null &&
                  answer == null &&
                  !filters.missingWaiver &&
                  filters.registrationStatus == null,
              onTap: _filtersController.clear,
            ),
            if (filters.group == null)
              CpFilterChip(
                key: const Key('people.roster.groupFilter'),
                label: words.one('group'),
                menu: true,
                onTap: _pickGroup,
              )
            else
              CpFilterChip(
                key: const Key('people.roster.groupChip'),
                label: filters.group!.name,
                selected: true,
                onTap: _pickGroup,
                onClear: () => _filtersController.setGroup(null),
                clearKey: const Key('people.roster.groupChip.clear'),
                clearTooltip: strings.clearGroup(words.one('group')),
              ),
            if (categories.isNotEmpty)
              if (filters.category == null)
                CpFilterChip(
                  key: const Key('people.roster.categoryFilter'),
                  label: words.one('category'),
                  menu: true,
                  onTap: () => _pickCategory(categories),
                )
              else
                CpFilterChip(
                  key: const Key('people.roster.categoryChip'),
                  label: filters.category!.name,
                  selected: true,
                  onTap: () => _pickCategory(categories),
                  onClear: () => _filtersController.setCategory(null),
                  clearKey: const Key('people.roster.categoryChip.clear'),
                  clearTooltip: fieldStrings.filterByCategory(
                    words.one('category'),
                  ),
                ),
            if (filterFields.isNotEmpty)
              if (answer == null)
                CpFilterChip(
                  key: const Key('people.roster.fieldFilter'),
                  label: words.one('customField'),
                  menu: true,
                  onTap: () => _pickAnswer(filterFields),
                )
              else
                CpFilterChip(
                  key: const Key('people.roster.fieldChip'),
                  label:
                      '${answer.field.label}: ${answer.value is bool ? ((answer.value as bool) ? fieldStrings.yes : fieldStrings.no) : answer.value}',
                  selected: true,
                  onTap: () => _pickAnswer(filterFields),
                  onClear: () => _filtersController.setAnswer(null),
                  clearKey: const Key('people.roster.fieldChip.clear'),
                  clearTooltip: fieldStrings.filterByField(
                    words.one('customField'),
                  ),
                ),
            // One registration status (#249).
            if (browses && event.can(me, 'registrations.manage'))
              if (filters.registrationStatus == null)
                CpFilterChip(
                  key: const Key('people.roster.statusFilter'),
                  label: context.strings.committee.statusFilter,
                  menu: true,
                  onTap: _pickStatus,
                )
              else
                CpFilterChip(
                  key: const Key('people.roster.statusChip'),
                  label: context.strings.committee.status(
                    filters.registrationStatus!,
                  ),
                  selected: true,
                  onTap: _pickStatus,
                  onClear: () => _filtersController.setRegistrationStatus(null),
                  clearKey: const Key('people.roster.statusChip.clear'),
                  clearTooltip: context.strings.committee.clearStatusFilter,
                ),
            // People still missing a waiver (#246, W-06).
            if (hasWaivers)
              CpFilterChip(
                key: const Key('people.roster.missingWaiver'),
                label: strings.missingWaiver,
                selected: filters.missingWaiver,
                onTap: () => _filtersController.setMissingWaiver(
                  !filters.missingWaiver,
                ),
              ),
          ],
        ),
      if (filters.missingWaiver &&
          browses &&
          event.can(me, 'registrations.manage'))
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CpButton.text(
            key: const Key('people.roster.sendReminders'),
            icon: CpIcons.authEmailField,
            label: strings.sendReminders,
            onPressed: _sendReminders,
          ),
        ),
      if (filters.group != null && edits)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CpButton.text(
            key: const Key('people.roster.groupManage'),
            icon: CpIcons.actionSettings,
            label: strings.manageGroup(words.one('group')),
            onPressed: () => _manageGroup(filters.group!),
          ),
        ),
      // A linked adult adds people to, and answers for, their own group
      // (Spec #186 Req 26), but never creates, renames or deletes one.
      for (final g in ownGroupNames.values)
        _OwnGroupHeader(
          event: event,
          group: g,
          enabled: event.status != EventStatus.archived,
          onAddPeople: () => _openGroupEntry(group: g),
          onEditAnswers: () => _openGroupEntry(group: g, editing: true),
        ),
      if (waiting > 0)
        CpCard(
          key: const Key('people.roster.linkRequests'),
          child: CpListRow(
            key: const Key('people.roster.linkRequests.open'),
            leading: Icon(
              CpIcons.statusDue,
              size: cp.sizes.iconMd,
              color: cp.colors.accent,
            ),
            title: context.strings.links.waiting(waiting),
            onTap: () =>
                context.push('/dashboard/event/${event.id}/people/links'),
          ),
        ),
      CpSectionHeader(
        title: total == null
            ? words.other('participant')
            : words.count('participant', total),
      ),
    ];

    final Widget results;
    if (!roster.started || (roster.loading && roster.items.isEmpty)) {
      results = KeyedSubtree(
        key: const Key('people.roster.loading'),
        child: CpLoadingState.rows(
          semanticLabel: words.other('participant'),
          rows: 4,
        ),
      );
    } else if (roster.error != null && roster.items.isEmpty) {
      results = _Failed(onRetry: _controller.loadMore);
    } else if (roster.items.isEmpty) {
      results = KeyedSubtree(
        key: const Key('people.roster.empty'),
        child: CpEmptyState(
          icon: CpIcons.members,
          title: strings.emptyTitle(words.other('participant')),
          message: strings.emptyHint(words.one('group')),
        ),
      );
    } else {
      results = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          CpCard(
            child: CpRowGroup(
              children: [
                for (final p in roster.items)
                  _PersonTile(
                    person: p,
                    selected: p.id == widget.selectedId,
                    groupName: [
                      if (p.groupId != null) ?roster.groups[p.groupId]?.name,
                      if (p.isChild) strings.child,
                      // The age band, never a birth date (Z-01).
                      if (p.categoryId != null) ?categoryNames[p.categoryId],
                      // Their registration's status (#249, Req 65).
                      if (p.registrationStatus case final status?)
                        context.strings.committee.status(status),
                    ].join(' · '),
                    onTap: () => _open(p.id),
                  ),
              ],
            ),
          ),
          if (roster.error != null)
            _Failed(onRetry: _controller.loadMore)
          else if (roster.hasMore)
            Center(
              child: roster.loading
                  ? CpLoadingState(semanticLabel: strings.loadMore)
                  : CpButton.text(
                      key: const Key('people.roster.more'),
                      label: strings.loadMore,
                      onPressed: _controller.loadMore,
                    ),
            ),
        ],
      );
    }

    final split = CpListDetail.isSplit(context);
    final side = split
        ? cp.space.lg
        : Breakpoints.screenHorizontalPadding(context);
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        key: const Key('people.roster.list'),
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(side, cp.space.sm, side, cp.space.xxl),
        children: [
          ContentMaxWidth(
            maxWidth: split ? double.infinity : cp.sizes.phoneColumn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.md,
              children: [
                ...header,
                results,
                Text(
                  strings.onlineNote,
                  key: const Key('people.roster.online'),
                  textAlign: TextAlign.center,
                  style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Your {group}" for a linked adult (Spec #186 Req 26): their group's
/// name, with "Add people" and "Edit answers".
class _OwnGroupHeader extends StatelessWidget {
  const _OwnGroupHeader({
    required this.event,
    required this.group,
    required this.enabled,
    required this.onAddPeople,
    required this.onEditAnswers,
  });

  final EventModel event;
  final GroupModel group;
  final bool enabled;
  final VoidCallback onAddPeople;
  final VoidCallback onEditAnswers;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.groupEntry;
    final words = event.words;
    return CpCard(
      key: Key('people.roster.ownGroup.${group.id}'),
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          Row(
            spacing: cp.space.md,
            children: [
              Container(
                width: cp.sizes.iconTile,
                height: cp.sizes.iconTile,
                decoration: BoxDecoration(
                  color: cp.colors.accentSoft,
                  borderRadius: cp.radii.sm,
                ),
                child: Icon(
                  CpIcons.members,
                  size: cp.sizes.iconMd,
                  color: cp.colors.accent,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.yourGroup(words.one('group')),
                      style: cp.type.labelSmall.copyWith(
                        color: cp.colors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      group.name,
                      style: cp.type.titleSmall.copyWith(color: cp.colors.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            spacing: cp.space.sm,
            runSpacing: cp.space.sm,
            children: [
              CpButton.secondary(
                key: Key('people.roster.ownGroup.${group.id}.addPeople'),
                icon: CpIcons.memberAdd,
                label: strings.addPeople(words.other('participant')),
                onPressed: enabled ? onAddPeople : null,
              ),
              CpButton.secondary(
                key: Key('people.roster.ownGroup.${group.id}.editAnswers'),
                icon: CpIcons.actionEdit,
                label: strings.editAnswers,
                onPressed: enabled ? onEditAnswers : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    this.groupName,
    this.selected = false,
    required this.onTap,
  });

  final ParticipantModel person;
  final String? groupName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Left by a deleted account (Req 14a).
    final name = person.name.isEmpty
        ? context.strings.links.unnamed
        : person.name;
    return Builder(
      // Its own context, inside the list and detail, so choosing another
      // person asks first when the open record has unsaved edits.
      builder: (row) => CpListRow(
        key: Key('people.tile.${person.id}'),
        leading: CpAvatar(name: person.name),
        title: name,
        subtitle: (groupName ?? '').isEmpty ? null : groupName,
        // The status with an icon and colour too (Req 71).
        trailing: person.registrationStatus == null
            ? null
            : RegistrationStatusIcon(status: person.registrationStatus!),
        selected: selected,
        onTap: () => CpListDetail.select(row, onTap),
      ),
    );
  }
}

/// A linked person's own record, when they look after no group (Req 46).
class _OwnRecord extends ConsumerWidget {
  const _OwnRecord({
    required this.eventId,
    required this.participantId,
    required this.selected,
    required this.onTap,
  });

  final String eventId;
  final String participantId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final key = (eventId: eventId, id: participantId);
    final person = ref.watch(participantProvider(key));
    final side = CpListDetail.isSplit(context)
        ? cp.space.lg
        : Breakpoints.screenHorizontalPadding(context);
    return ListView(
      key: const Key('people.roster.own'),
      padding: EdgeInsets.fromLTRB(side, cp.space.lg, side, cp.space.lg),
      children: [
        ContentMaxWidth(
          maxWidth: cp.sizes.phoneColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.md,
            children: [
              CpSectionHeader(title: context.strings.links.yourRecord),
              if (person.hasError && !person.hasValue)
                _Failed(onRetry: () => ref.invalidate(participantProvider(key)))
              else if (!person.hasValue)
                CpLoadingState(semanticLabel: context.strings.links.yourRecord)
              else if (person.value == null)
                const NoAccessView()
              else
                CpCard(
                  child: _PersonTile(
                    person: person.value!,
                    selected: selected,
                    onTap: onTap,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.people;
    return CpErrorState(
      key: const Key('people.roster.error'),
      title: strings.loadFailed,
      retryLabel: strings.retry,
      retryKey: const Key('people.roster.retry'),
      onRetry: onRetry,
    );
  }
}
