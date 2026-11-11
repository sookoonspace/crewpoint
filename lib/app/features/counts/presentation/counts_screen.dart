import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart'
    show NoAccessView;
import 'package:crewpoint_app/app/core/services/file_export_service.dart';
import 'package:crewpoint_app/app/features/counts/domain/count_export.dart';
import 'package:crewpoint_app/app/features/counts/domain/event_stats.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart'
    show eventFieldsProvider;
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:crewpoint_app/app/features/schedule/presentation/session_tile.dart'
    show sessionTimeLabel;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// `counts` (Req 52): headcounts for the event and each session, by category
/// and by each choice or yes/no field, worked out on the server, with when
/// they were last updated. Needs `counts.read`.
class CountsScreen extends ConsumerStatefulWidget {
  const CountsScreen({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<CountsScreen> createState() => _CountsScreenState();
}

class _CountsScreenState extends ConsumerState<CountsScreen> {
  bool _busy = false;
  String? _error;

  /// The freeze to compare with, or null for the latest.
  String? _freezeId;

  bool get _exports =>
      widget.event.can(ref.read(currentUserIdProvider) ?? '', 'reports.export');

  CountLabels _labels() {
    final strings = context.strings.counts;
    return CountLabels(
      wholeEvent: strings.wholeEventLabel,
      noAnswer: strings.noAnswer,
      noCategory: strings.noCategory,
      yes: strings.yes,
      no: strings.no,
    );
  }

  List<CustomField> get _fields =>
      ref.read(eventFieldsProvider(widget.event.id)).value ?? const [];

  List<SessionModel> get _sessions =>
      ref.read(sessionListProvider(widget.event.id)).value ?? const [];

  Future<void> _share(String csv, String kind) => ref
      .read(fileExporterProvider)
      .share(
        bytes: utf8.encode(csv),
        filename: buildExportFilename(
          eventTitle: widget.event.title,
          kind: kind,
          extension: 'csv',
          date: DateTime.now(),
        ),
        mimeType: 'text/csv',
      );

  /// What to export: counts, the roster, or changes since the freeze, with
  /// private fields left out unless chosen (Req 53).
  Future<void> _export(EventStats stats, FrozenCounts? freeze) async {
    final strings = context.strings.counts;
    final me = ref.read(currentUserIdProvider) ?? '';
    final readsPrivate = widget.event.can(me, 'participants.readPrivate');
    final readsRoster = widget.event.can(me, 'participants.read');
    var includePrivate = false;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => ListView(
          key: const Key('counts.export.sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              strings.exportTitle,
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
            SwitchListTile(
              key: const Key('counts.export.private'),
              contentPadding: EdgeInsets.zero,
              title: Text(strings.includePrivate),
              subtitle: Text(strings.includePrivateHelp),
              value: includePrivate,
              onChanged: (v) => setSheet(() => includePrivate = v),
            ),
            ListTile(
              key: const Key('counts.export.counts'),
              leading: const Icon(AppIcons.members),
              title: Text(strings.exportCounts),
              onTap: () => Navigator.of(sheet).pop('counts'),
            ),
            if (readsRoster)
              ListTile(
                key: const Key('counts.export.roster'),
                leading: const Icon(AppIcons.member),
                title: Text(strings.exportRoster),
                // The roster's private details need readPrivate.
                enabled: !includePrivate || readsPrivate,
                onTap: () => Navigator.of(sheet).pop('roster'),
              ),
            if (freeze != null)
              ListTile(
                key: const Key('counts.export.changes'),
                leading: const Icon(AppIcons.actionSwap),
                title: Text(strings.exportChanges),
                onTap: () => Navigator.of(sheet).pop('changes'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final labels = _labels();
    try {
      switch (choice) {
        case 'counts':
          await _share(
            countsCsv(
              event: widget.event,
              stats: stats,
              sessions: _sessions,
              fields: _fields,
              includePrivate: includePrivate,
              labels: labels,
            ),
            'counts',
          );
        case 'roster':
          await _share(
            await ref
                .read(memberCallsProvider)
                .exportRoster(widget.event.id, includePrivate: includePrivate),
            'roster',
          );
        case 'changes':
          await _share(
            changesCsv(
              countChanges(
                frozen: freeze!.stats,
                current: stats,
                sessions: _sessions,
                fields: _fields,
                event: widget.event,
                includePrivate: includePrivate,
                labels: labels,
              ),
            ),
            'count-changes',
          );
      }
      messenger.showSnackBar(SnackBar(content: Text(strings.exported)));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          key: const Key('counts.export.failed'),
          content: Text(strings.exportFailed),
          action: SnackBarAction(
            label: strings.retry,
            onPressed: () => _export(stats, freeze),
          ),
        ),
      );
    }
  }

  /// Keeps today's numbers for suppliers (Req 54).
  Future<void> _freeze() async {
    final strings = context.strings.counts;
    // The label typed, or null when cancelled.
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _FreezeDialog(),
    );
    if (text == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(memberCallsProvider)
          .freezeCounts(widget.event.id, label: text.isEmpty ? null : text);
      _freezeId = null;
      messenger.showSnackBar(SnackBar(content: Text(strings.frozenNow)));
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = isConnectionFailure(e)
              ? strings.needsConnection
              : strings.freezeFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recalculate() async {
    final strings = context.strings.counts;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(memberCallsProvider).recalculateCounts(widget.event.id);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = isConnectionFailure(e)
              ? strings.needsConnection
              : strings.recalculateFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.counts;
    final event = widget.event;
    final me = ref.watch(currentUserIdProvider) ?? '';
    if (!event.can(me, 'counts.read')) {
      return Scaffold(appBar: AppBar(), body: const NoAccessView());
    }
    final stats = ref.watch(eventStatsProvider(event.id));

    final Widget body = switch (stats) {
      AsyncValue(hasValue: true, :final value) =>
        value == null ? _notYet() : _counts(value),
      AsyncValue(error: _?) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.md,
            children: [
              Text(
                strings.loadFailed,
                key: const Key('counts.error'),
                textAlign: TextAlign.center,
              ),
              FilledButton.icon(
                key: const Key('counts.retry'),
                onPressed: () => ref.invalidate(eventStatsProvider(event.id)),
                icon: const Icon(AppIcons.actionRetry),
                label: Text(strings.retry),
              ),
            ],
          ),
        ),
      ),
      _ => const Center(
        child: CircularProgressIndicator(key: Key('counts.loading')),
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.title),
        elevation: 0,
        actions: [
          if (_exports && (stats.value != null))
            IconButton(
              key: const Key('counts.export'),
              tooltip: strings.export,
              icon: Icon(AppIcons.actionShare),
              onPressed: () => _export(
                stats.value!,
                _chosenFreeze(ref.read(countFreezesProvider(event.id)).value),
              ),
            ),
        ],
      ),
      body: ContentMaxWidth(maxWidth: 720, child: body),
    );
  }

  Widget _recalculateButton({required String label}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.sm,
    children: [
      FilledButton.tonalIcon(
        key: const Key('counts.recalculate'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: _busy ? null : _recalculate,
        icon: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(AppIcons.actionRetry),
        label: Text(_busy ? context.strings.counts.recalculating : label),
      ),
      if (_error != null)
        Text(
          _error!,
          key: const Key('counts.recalculateError'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
    ],
  );

  Widget _notYet() {
    final strings = context.strings.counts;
    final theme = Theme.of(context);
    return ListView(
      key: const Key('counts.empty'),
      padding: EdgeInsets.all(Breakpoints.screenHorizontalPadding(context)),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          AppIcons.members,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          strings.notYet,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        Text(strings.notYetHelp, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        _recalculateButton(label: strings.countNow),
      ],
    );
  }

  Widget _counts(EventStats stats) {
    final strings = context.strings.counts;
    final theme = Theme.of(context);
    final event = widget.event;
    final categories = {
      for (final c in categoriesOf(event.settings)) c.id: c.name,
    };
    final fields = [
      for (final f
          in ref.watch(eventFieldsProvider(event.id)).value ??
              const <CustomField>[])
        if (f.type == FieldType.singleChoice ||
            f.type == FieldType.multiChoice ||
            f.type == FieldType.yesNo)
          f,
    ]..sort((a, b) => a.order.compareTo(b.order));
    final sessions = [
      ...ref.watch(sessionListProvider(event.id)).value ??
          const <SessionModel>[],
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    final updated = stats.updatedAt;
    final padding = Breakpoints.screenHorizontalPadding(context);

    return ListView(
      key: const Key('counts.list'),
      padding: EdgeInsets.fromLTRB(padding, AppSpacing.md, padding, 48),
      children: [
        if (updated != null)
          Text(
            strings.updated(
              DateFormat.MMMd().add_jm().format(updated.toLocal()),
            ),
            key: const Key('counts.updated'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        Text(strings.recalculateHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        _recalculateButton(label: strings.recalculate),
        if (_exports)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: OutlinedButton.icon(
              key: const Key('counts.freeze'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy ? null : _freeze,
              icon: const Icon(AppIcons.lock),
              label: Text(strings.freeze),
            ),
          ),
        ..._freezeSection(stats, fields, sessions),
        const SizedBox(height: AppSpacing.lg),
        Card(
          key: const Key('counts.event'),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.sm,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    strings.wholeEvent,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${strings.people(stats.event.total)} · '
                  '${strings.groups(stats.groups, event.words.other('group'))}',
                  key: const Key('counts.event.total'),
                  style: theme.textTheme.headlineSmall,
                ),
                ..._breakdown(stats.event, 'event', categories, fields),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            strings.sessionsHeading,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (stats.sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              strings.noSessions,
              key: const Key('counts.sessions.none'),
            ),
          ),
        for (final s in sessions)
          if (stats.sessions[s.id] case final tally?)
            ExpansionTile(
              key: Key('counts.session.${s.id}'),
              tilePadding: EdgeInsets.zero,
              title: Text(s.title),
              subtitle: Text(sessionTimeLabel(event, s, withDay: true)),
              trailing: Text(
                '${tally.total}',
                key: Key('counts.session.${s.id}.total'),
                style: theme.textTheme.titleLarge,
              ),
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: _breakdown(tally, 's.${s.id}', categories, fields),
            ),
      ],
    );
  }

  FrozenCounts? _chosenFreeze(List<FrozenCounts>? freezes) {
    if (freezes == null || freezes.isEmpty) return null;
    return freezes.where((f) => f.id == _freezeId).firstOrNull ?? freezes.first;
  }

  /// The freeze to compare with and what changed since (Req 54).
  List<Widget> _freezeSection(
    EventStats stats,
    List<CustomField> fields,
    List<SessionModel> sessions,
  ) {
    final strings = context.strings.counts;
    final theme = Theme.of(context);
    final freezes =
        ref.watch(countFreezesProvider(widget.event.id)).value ?? const [];
    final freeze = _chosenFreeze(freezes);
    if (freeze == null) return const [];
    String when(FrozenCounts f) => f.frozenAt == null
        ? ''
        : DateFormat.MMMd().add_jm().format(f.frozenAt!.toLocal());
    final changes = countChanges(
      frozen: freeze.stats,
      current: stats,
      sessions: sessions,
      fields: fields,
      event: widget.event,
      includePrivate: true,
      labels: _labels(),
    );
    return [
      const SizedBox(height: AppSpacing.lg),
      Card(
        key: const Key('counts.frozen'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.sm,
            children: [
              if (freezes.length > 1)
                DropdownButtonFormField<String>(
                  key: const Key('counts.frozen.pick'),
                  initialValue: freeze.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: strings.earlierFreezes,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final f in freezes)
                      DropdownMenuItem(
                        value: f.id,
                        child: Text(strings.frozenOn(when(f), f.label)),
                      ),
                  ],
                  onChanged: (id) => setState(() => _freezeId = id),
                )
              else
                Text(
                  strings.frozenOn(when(freeze), freeze.label),
                  key: const Key('counts.frozen.when'),
                  style: theme.textTheme.titleSmall,
                ),
              Semantics(
                header: true,
                child: Text(
                  strings.changesHeading,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (changes.isEmpty)
                Text(strings.noChanges, key: const Key('counts.changes.none'))
              else
                for (final (i, c) in changes.indexed)
                  Text(
                    '${c.where} · ${strings.change(c.what, c.before, c.after)}',
                    key: Key('counts.changes.$i'),
                  ),
            ],
          ),
        ),
      ),
    ];
  }

  /// Counts by category, then by each field, as rows of label and number.
  List<Widget> _breakdown(
    CountTally tally,
    String keyPart,
    Map<String, String> categories,
    List<CustomField> fields,
  ) {
    final strings = context.strings.counts;
    final theme = Theme.of(context);
    Widget row(String label, int n, String key) => Semantics(
      label: '$label: $n',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text('$n', key: Key(key), style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
    String option(CustomField f, String key) => key == noAnswer
        ? strings.noAnswer
        : f.type == FieldType.yesNo
        ? (key == 'yes' ? strings.yes : strings.no)
        : key;

    return [
      if (tally.byCategory.isNotEmpty) ...[
        Text(strings.byCategory, style: theme.textTheme.labelLarge),
        for (final e in tally.categoriesSorted)
          row(
            e.key == noAnswer ? strings.noCategory : categories[e.key] ?? e.key,
            e.value,
            'counts.$keyPart.category.${e.key}',
          ),
      ],
      for (final f in fields)
        if (tally.byField[f.id]?.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(f.label, style: theme.textTheme.labelLarge),
          for (final e in tally.sorted(f.id))
            row(
              option(f, e.key),
              e.value,
              'counts.$keyPart.field.${f.id}.${e.key}',
            ),
        ],
    ];
  }
}

/// Asks before freezing, with an optional note. Pops the note, or null when
/// cancelled.
class _FreezeDialog extends StatefulWidget {
  const _FreezeDialog();

  @override
  State<_FreezeDialog> createState() => _FreezeDialogState();
}

class _FreezeDialogState extends State<_FreezeDialog> {
  final _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.counts;
    return AlertDialog(
      title: Text(strings.freezeTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: [
            Text(strings.freezeBody),
            TextField(
              key: const Key('counts.freeze.label'),
              controller: _label,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: strings.freezeLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('counts.freeze.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('counts.freeze.confirm'),
          onPressed: () => Navigator.of(context).pop(_label.text.trim()),
          child: Text(strings.freezeConfirm),
        ),
      ],
    );
  }
}
