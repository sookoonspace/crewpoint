import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart'
    show AdminScaffold, NoAccessView;
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
    final choice = await showCpSheet<String>(
      context: context,
      title: strings.exportTitle,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Column(
          key: const Key('counts.export.sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: sheet.cp.space.lg,
          children: [
            CpSwitchRow(
              key: const Key('counts.export.private'),
              title: strings.includePrivate,
              help: strings.includePrivateHelp,
              value: includePrivate,
              onChanged: (v) => setSheet(() => includePrivate = v),
            ),
            CpCard(
              child: CpRowGroup(
                children: [
                  CpListRow(
                    key: const Key('counts.export.counts'),
                    leading: const _RowIcon(CpIcons.members),
                    title: strings.exportCounts,
                    onTap: () => Navigator.of(sheet).pop('counts'),
                  ),
                  if (readsRoster)
                    CpListRow(
                      key: const Key('counts.export.roster'),
                      leading: const _RowIcon(CpIcons.member),
                      title: strings.exportRoster,
                      // The roster's private details need readPrivate.
                      onTap: !includePrivate || readsPrivate
                          ? () => Navigator.of(sheet).pop('roster')
                          : null,
                    ),
                  if (freeze != null)
                    CpListRow(
                      key: const Key('counts.export.changes'),
                      leading: const _RowIcon(CpIcons.actionSwap),
                      title: strings.exportChanges,
                      onTap: () => Navigator.of(sheet).pop('changes'),
                    ),
                ],
              ),
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
      return AdminScaffold(title: strings.title, body: const NoAccessView());
    }
    final stats = ref.watch(eventStatsProvider(event.id));

    final Widget body = switch (stats) {
      AsyncValue(hasValue: true, :final value) =>
        value == null ? _notYet() : _counts(value),
      AsyncValue(error: _?) => CpErrorState(
        key: const Key('counts.error'),
        title: strings.loadFailed,
        retryLabel: strings.retry,
        retryKey: const Key('counts.retry'),
        onRetry: () => ref.invalidate(eventStatsProvider(event.id)),
      ),
      _ => CpLoadingState.rows(
        key: const Key('counts.loading'),
        semanticLabel: strings.title,
      ),
    };

    return AdminScaffold(
      title: strings.title,
      actions: [
        if (_exports && (stats.value != null))
          CpTopBarAction(
            key: const Key('counts.export'),
            tooltip: strings.export,
            icon: CpIcons.actionShare,
            onPressed: () => _export(
              stats.value!,
              _chosenFreeze(ref.read(countFreezesProvider(event.id)).value),
            ),
          ),
      ],
      body: body,
    );
  }

  /// The page's scrolling column, as on the other admin screens.
  Widget _page({required Key key, required List<Widget> children}) {
    final cp = context.cp;
    return ListView(
      key: key,
      padding: EdgeInsets.fromLTRB(
        cp.space.lg,
        cp.space.sm,
        cp.space.lg,
        cp.space.xxl,
      ),
      children: [
        ContentMaxWidth(
          maxWidth: cp.sizes.phoneColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.lg,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _recalculateButton({required String label}) => CpButton.secondary(
    key: const Key('counts.recalculate'),
    label: _busy ? context.strings.counts.recalculating : label,
    icon: CpIcons.actionRetry,
    busy: _busy,
    expand: true,
    onPressed: _recalculate,
  );

  Widget? _errorText() => _error == null
      ? null
      : CpFieldError(_error!, key: const Key('counts.recalculateError'));

  Widget _notYet() {
    final cp = context.cp;
    final strings = context.strings.counts;
    return _page(
      key: const Key('counts.empty'),
      children: [
        CpCard(
          padding: EdgeInsets.all(cp.space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.md,
            children: [
              Icon(
                CpIcons.counts,
                size: cp.sizes.iconXl,
                color: cp.colors.textMuted,
              ),
              Text(
                strings.notYet,
                textAlign: TextAlign.center,
                style: cp.type.titleMedium.copyWith(color: cp.colors.text),
              ),
              Text(
                strings.notYetHelp,
                textAlign: TextAlign.center,
                style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
              ),
              _recalculateButton(label: strings.countNow),
              ?_errorText(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _counts(EventStats stats) {
    final cp = context.cp;
    final strings = context.strings.counts;
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
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);
    final counted = [
      for (final s in sessions)
        if (stats.sessions[s.id] case final tally?) (s, tally),
    ];

    return _page(
      key: const Key('counts.list'),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: cp.space.xs,
          children: [
            if (updated != null)
              Text(
                strings.updated(
                  DateFormat.MMMd().add_jm().format(updated.toLocal()),
                ),
                key: const Key('counts.updated'),
                style: cp.type.titleSmall.copyWith(color: cp.colors.text),
              ),
            Text(strings.recalculateHelp, style: muted),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: cp.space.sm,
          children: [
            _recalculateButton(label: strings.recalculate),
            if (_exports)
              CpButton.secondary(
                key: const Key('counts.freeze'),
                label: strings.freeze,
                icon: CpIcons.lock,
                expand: true,
                onPressed: _busy ? null : _freeze,
              ),
            ?_errorText(),
          ],
        ),
        ?_freezeCard(stats, fields, sessions),
        CpCard(
          key: const Key('counts.event'),
          padding: EdgeInsets.all(cp.space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.sm,
            children: [
              Semantics(
                header: true,
                child: Text(
                  strings.wholeEvent,
                  style: cp.type.titleMedium.copyWith(color: cp.colors.text),
                ),
              ),
              Text(
                '${strings.people(stats.event.total)} · '
                '${strings.groups(stats.groups, event.words.other('group'))}',
                key: const Key('counts.event.total'),
                style: cp.type.headlineSmall.copyWith(color: cp.colors.text),
              ),
              if (!stats.notConfirmed.isEmpty)
                Text(
                  strings.notConfirmed(
                    groups: strings.groups(
                      stats.notConfirmed.groups,
                      event.words.other('group'),
                    ),
                    people: strings.people(stats.notConfirmed.people),
                    pending: stats.notConfirmed.pending.people,
                    waitlisted: stats.notConfirmed.waitlisted.people,
                    drafts: stats.notConfirmed.draft.people,
                  ),
                  key: const Key('counts.event.notConfirmed'),
                  style: muted,
                ),
              ..._breakdown(stats.event, 'event', categories, fields),
            ],
          ),
        ),
        if (stats.photoConsent case final photo?) ...[
          CpSectionHeader(title: context.strings.photoConsent.countsHeading),
          CpStatGrid(
            key: const Key('counts.photoConsent'),
            children: [
              CpStatCard(
                key: const Key('counts.photoConsent.yes'),
                icon: CpIcons.statusDone,
                label: context.strings.photoConsent.yes,
                value: '${photo.yes}',
              ),
              CpStatCard(
                key: const Key('counts.photoConsent.no'),
                icon: CpIcons.blocked,
                label: context.strings.photoConsent.no,
                value: '${photo.no}',
              ),
              CpStatCard(
                key: const Key('counts.photoConsent.unanswered'),
                icon: CpIcons.statusInfo,
                label: context.strings.photoConsent.unanswered,
                value: '${photo.unanswered}',
              ),
            ],
          ),
        ],
        CpSectionHeader(title: strings.sessionsHeading),
        if (stats.sessions.isEmpty)
          Text(
            strings.noSessions,
            key: const Key('counts.sessions.none'),
            style: muted,
          ),
        if (counted.isNotEmpty)
          CpCard(
            child: CpRowGroup(
              children: [
                for (final (s, tally) in counted)
                  ExpansionTile(
                    key: Key('counts.session.${s.id}'),
                    // No extra lines above and below an opened session.
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: EdgeInsets.symmetric(horizontal: cp.space.lg),
                    title: Text(
                      s.title,
                      style: cp.type.titleSmall.copyWith(color: cp.colors.text),
                    ),
                    subtitle: Text(
                      sessionTimeLabel(event, s, withDay: true),
                      style: cp.type.bodySmall.copyWith(
                        color: cp.colors.textMuted,
                      ),
                    ),
                    trailing: Text(
                      '${tally.total}',
                      key: Key('counts.session.${s.id}.total'),
                      style: cp.type.titleLarge.copyWith(color: cp.colors.text),
                    ),
                    childrenPadding: EdgeInsets.fromLTRB(
                      cp.space.lg,
                      0,
                      cp.space.lg,
                      cp.space.md,
                    ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _breakdown(
                      tally,
                      's.${s.id}',
                      categories,
                      fields,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  FrozenCounts? _chosenFreeze(List<FrozenCounts>? freezes) {
    if (freezes == null || freezes.isEmpty) return null;
    return freezes.where((f) => f.id == _freezeId).firstOrNull ?? freezes.first;
  }

  /// Picks which freeze to compare with.
  Future<void> _pickFreeze(
    List<FrozenCounts> freezes,
    FrozenCounts current,
    String Function(FrozenCounts) label,
  ) async {
    final cp = context.cp;
    final picked = await showCpSheet<String>(
      context: context,
      title: context.strings.counts.earlierFreezes,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final f in freezes)
              CpListRow(
                key: Key('counts.frozen.pick.${f.id}'),
                title: label(f),
                selected: f.id == current.id,
                trailing: f.id == current.id
                    ? Icon(
                        CpIcons.statusDone,
                        size: cp.sizes.iconMd,
                        color: cp.colors.accent,
                      )
                    : const SizedBox.shrink(),
                onTap: () => Navigator.of(sheet).pop(f.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _freezeId = picked);
  }

  /// The freeze to compare with and what changed since (Req 54).
  Widget? _freezeCard(
    EventStats stats,
    List<CustomField> fields,
    List<SessionModel> sessions,
  ) {
    final cp = context.cp;
    final strings = context.strings.counts;
    final freezes =
        ref.watch(countFreezesProvider(widget.event.id)).value ?? const [];
    final freeze = _chosenFreeze(freezes);
    if (freeze == null) return null;
    String when(FrozenCounts f) => f.frozenAt == null
        ? ''
        : DateFormat.MMMd().add_jm().format(f.frozenAt!.toLocal());
    String label(FrozenCounts f) => strings.frozenOn(when(f), f.label);
    final changes = countChanges(
      frozen: freeze.stats,
      current: stats,
      sessions: sessions,
      fields: fields,
      event: widget.event,
      includePrivate: true,
      labels: _labels(),
    );
    final body = cp.type.bodyMedium.copyWith(color: cp.colors.text);
    return CpCard(
      key: const Key('counts.frozen'),
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.sm,
        children: [
          if (freezes.length > 1)
            CpSelectField(
              fieldKey: const Key('counts.frozen.pick'),
              label: strings.earlierFreezes,
              value: label(freeze),
              leadingIcon: CpIcons.lock,
              onTap: () => _pickFreeze(freezes, freeze, label),
            )
          else
            Text(
              label(freeze),
              key: const Key('counts.frozen.when'),
              style: cp.type.titleSmall.copyWith(color: cp.colors.text),
            ),
          Semantics(
            header: true,
            child: Text(
              strings.changesHeading,
              style: cp.type.titleMedium.copyWith(color: cp.colors.text),
            ),
          ),
          if (changes.isEmpty)
            Text(
              strings.noChanges,
              key: const Key('counts.changes.none'),
              style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
            )
          else
            for (final (i, c) in changes.indexed)
              Text(
                '${c.where} · ${strings.change(c.what, c.before, c.after)}',
                key: Key('counts.changes.$i'),
                style: body,
              ),
        ],
      ),
    );
  }

  /// Counts by category, then by each field, as rows of label and number.
  List<Widget> _breakdown(
    CountTally tally,
    String keyPart,
    Map<String, String> categories,
    List<CustomField> fields,
  ) {
    final cp = context.cp;
    final strings = context.strings.counts;
    final heading = cp.type.labelLarge.copyWith(color: cp.colors.textMuted);
    Widget row(String label, int n, String key) => Semantics(
      label: '$label: $n',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: cp.space.xs / 2),
        child: Row(
          spacing: cp.space.md,
          children: [
            Expanded(
              child: Text(
                label,
                style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
              ),
            ),
            Text(
              '$n',
              key: Key(key),
              style: cp.type.titleSmall.copyWith(color: cp.colors.text),
            ),
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
        Padding(
          padding: EdgeInsets.only(top: cp.space.sm),
          child: Text(strings.byCategory, style: heading),
        ),
        for (final e in tally.categoriesSorted)
          row(
            e.key == noAnswer ? strings.noCategory : categories[e.key] ?? e.key,
            e.value,
            'counts.$keyPart.category.${e.key}',
          ),
      ],
      for (final f in fields)
        if (tally.byField[f.id]?.isNotEmpty ?? false) ...[
          Padding(
            padding: EdgeInsets.only(top: cp.space.sm),
            child: Text(f.label, style: heading),
          ),
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

/// A row's icon in the export sheet.
class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Icon(icon, size: cp.sizes.iconMd, color: cp.colors.textMuted);
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
    return CpDialog(
      title: strings.freezeTitle,
      message: strings.freezeBody,
      content: CpTextField(
        fieldKey: const Key('counts.freeze.label'),
        label: strings.freezeLabel,
        controller: _label,
        maxLength: 80,
      ),
      actions: [
        CpButton.text(
          key: const Key('counts.freeze.cancel'),
          label: strings.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        CpButton(
          key: const Key('counts.freeze.confirm'),
          label: strings.freezeConfirm,
          onPressed: () => Navigator.of(context).pop(_label.text.trim()),
        ),
      ],
    );
  }
}
