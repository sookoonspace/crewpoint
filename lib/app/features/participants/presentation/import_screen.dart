import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/file_picker_service.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/import_job.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/import_mapping.dart';
import 'package:crewpoint_app/app/features/participants/presentation/group_sheets.dart';

/// Imports a roster from CSV (Req 44, 45, 75; route `people/import`). Needs
/// `participants.import`. Choose a file, say what each column holds, check
/// it, then import the ready rows. The job runs on the server, so this
/// screen can be left and reopened (`?job=`) for its report.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.event, this.jobId});

  final EventModel event;
  final String? jobId;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  PickedFile? _file;
  CsvPreview? _preview;
  List<String> _targets = const [];
  String? _jobId;
  bool _busy = false;
  String? _error;
  final Set<String> _toCancel = {};

  @override
  void initState() {
    super.initState();
    _jobId = widget.jobId;
  }

  /// A file is chosen but not yet checked.
  bool get _unsaved => _file != null && _jobId == null;

  Future<void> _pick(List<CustomField> fields) async {
    final strings = context.strings.imports;
    final file = await ref.read(filePickerProvider).pickCsv();
    if (file == null || !mounted) return;
    try {
      final preview = previewCsv(utf8.decode(file.bytes, allowMalformed: true));
      final words = widget.event.words;
      setState(() {
        _file = file;
        _preview = preview;
        _targets = guessTargets(
          preview.header,
          fields,
          words: {
            'group': [words.one('group'), words.other('group')],
            'name': [words.one('participant')],
            'category': [words.one('category')],
          },
        );
        _error = null;
      });
    } on FormatException {
      setState(() {
        _file = null;
        _preview = null;
        _error = strings.unreadable;
      });
    }
  }

  Future<void> _check() async {
    final file = _file;
    final preview = _preview;
    if (file == null || preview == null) return;
    final strings = context.strings.imports;
    final jobId = newGroupId();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(importRepositoryProvider)
          .start(
            eventId: widget.event.id,
            jobId: jobId,
            fileName: file.name,
            bytes: file.bytes,
            header: preview.header,
            targets: _targets,
            createdBy: ref.read(currentUserIdProvider) ?? '',
          );
      if (mounted) setState(() => _jobId = jobId);
    } catch (_) {
      // The mapping is kept, so trying again needs no new choices.
      if (mounted) setState(() => _error = strings.uploadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(ImportJob job) async {
    final strings = context.strings.imports;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(importRepositoryProvider)
          .queueApply(eventId: widget.event.id, jobId: job.id);
    } catch (_) {
      if (mounted) setState(() => _error = strings.uploadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelMissing(ImportJob job) async {
    final strings = context.strings.imports;
    final messenger = ScaffoldMessenger.of(context);
    final ids = _toCancel.toList()..sort();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(memberCallsProvider)
          .cancelImportedGroups(
            eventId: widget.event.id,
            jobId: job.id,
            groupIds: ids,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(strings.cancelled(ids.length))),
      );
      setState(_toCancel.clear);
      ref.read(rosterProvider(widget.event.id).notifier).refresh();
    } catch (_) {
      if (mounted) setState(() => _error = strings.cancelFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startOver() => setState(() {
    _jobId = null;
    _file = null;
    _preview = null;
    _targets = const [];
    _error = null;
    _toCancel.clear();
  });

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final words = event.words;
    final strings = context.strings.imports;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final title = strings.title(words.other('participant'));

    Widget scaffold(Widget body) => PopScope(
      canPop: !_unsaved || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context) && mounted) {
          _startOver();
          navigator.pop();
        }
      },
      child: AdminScaffold(title: title, body: body),
    );

    if (!event.can(me, 'participants.import')) {
      return scaffold(const NoAccessView());
    }
    final cp = context.cp;
    final fields =
        ref.watch(eventFieldsProvider(event.id)).value ?? const <CustomField>[];
    final fieldsById = {for (final f in fields) f.id: f};
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);

    final List<Widget> children;
    final jobId = _jobId;
    if (jobId != null) {
      children = _jobView(jobId, strings, fieldsById);
    } else {
      final preview = _preview;
      children = [
        AdminNote(strings.intro),
        AdminNote(
          strings.needsConnection,
          key: const Key('people.import.online'),
          icon: CpIcons.wifiOff,
        ),
        if (preview == null) ..._recent(strings),
        CpButton.secondary(
          key: const Key('people.import.pick'),
          label: _file == null ? strings.pick : strings.pickAnother,
          icon: CpIcons.importFile,
          expand: true,
          onPressed: _busy ? null : () => _pick(fields),
        ),
        if (preview != null) ...[
          CpCard(
            padding: EdgeInsets.all(cp.space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.lg,
              children: [
                Text(
                  strings.fileSummary(_file!.name, preview.rowCount),
                  key: const Key('people.import.file'),
                  style: cp.type.titleSmall.copyWith(color: cp.colors.text),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: cp.space.xs,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        strings.mappingHeading,
                        style: cp.type.titleMedium.copyWith(
                          color: cp.colors.text,
                        ),
                      ),
                    ),
                    Text(strings.mappingHelp, style: muted),
                  ],
                ),
                for (var i = 0; i < preview.header.length; i++)
                  _ColumnMapping(
                    index: i,
                    header: preview.header[i],
                    sample: [
                      for (final r in preview.rows)
                        if (i < r.length && r[i].isNotEmpty) r[i],
                    ].take(2).join(', '),
                    value: _targets[i],
                    fields: fields,
                    enabled: !_busy,
                    onChanged: (t) => setState(() {
                      _targets = [
                        for (var j = 0; j < _targets.length; j++)
                          j == i
                              ? t
                              : (t != 'ignore' && _targets[j] == t
                                    ? 'ignore'
                                    : _targets[j]),
                      ];
                    }),
                  ),
                if (mappingProblem(_targets) != null)
                  CpFieldError(
                    strings.nameNotMapped,
                    key: const Key('people.import.nameNotMapped'),
                  ),
              ],
            ),
          ),
          CpButton(
            key: const Key('people.import.check'),
            label: strings.check,
            busy: _busy,
            expand: true,
            onPressed: mappingProblem(_targets) == null ? _check : null,
          ),
        ],
        ?_errorText(),
      ];
    }

    return scaffold(
      AdminList(listKey: const Key('people.import.body'), children: children),
    );
  }

  Widget? _errorText() => _error == null
      ? null
      : CpFieldError(_error!, key: const Key('people.import.error'));

  List<Widget> _recent(ImportStrings strings) {
    final cp = context.cp;
    final recent = ref.watch(recentImportsProvider(widget.event.id)).value;
    if (recent == null || recent.isEmpty) return const [];
    return [
      CpSectionHeader(title: strings.recentHeading),
      CpCard(
        child: CpRowGroup(
          children: [
            for (final job in recent)
              CpListRow(
                key: Key('people.import.job.${job.id}'),
                leading: Icon(
                  CpIcons.importFile,
                  size: cp.sizes.iconMd,
                  color: cp.colors.textMuted,
                ),
                title: job.fileName,
                subtitle: strings.statusName(job.status.name),
                onTap: () => setState(() => _jobId = job.id),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _jobView(
    String jobId,
    ImportStrings strings,
    Map<String, CustomField> fieldsById,
  ) {
    final cp = context.cp;
    final asyncJob = ref.watch(
      importJobProvider((eventId: widget.event.id, jobId: jobId)),
    );
    if (asyncJob.hasError && !asyncJob.hasValue) {
      return [
        LoadFailedView(
          onRetry: () => ref.invalidate(
            importJobProvider((eventId: widget.event.id, jobId: jobId)),
          ),
        ),
      ];
    }
    final job = asyncJob.value;
    if (job == null) {
      return [
        CpLoadingState(
          key: const Key('people.import.loading'),
          semanticLabel: strings.checking,
        ),
      ];
    }
    final words = widget.event.words;
    final report = job.report;
    final progress = job.progress;
    final body = cp.type.bodyMedium.copyWith(color: cp.colors.text);
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);
    final heading = cp.type.titleSmall.copyWith(color: cp.colors.text);
    // What the server said about the file, in one card.
    final card = <Widget>[
      Row(
        spacing: cp.space.sm,
        children: [
          Icon(
            CpIcons.importFile,
            size: cp.sizes.iconMd,
            color: cp.colors.textMuted,
          ),
          Expanded(child: Text(job.fileName, style: heading)),
        ],
      ),
    ];
    final out = <Widget>[];
    Widget wrap() => CpCard(
      key: const Key('people.import.job'),
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: card,
      ),
    );

    if (job.isWorking) {
      final applying = job.mode == 'apply';
      card.addAll([
        Text(
          applying
              ? (progress == null
                    ? strings.queued
                    : strings.progress(progress.processed, progress.total))
              : strings.checking,
          key: const Key('people.import.status'),
          style: body,
        ),
        ClipRRect(
          borderRadius: cp.radii.sm,
          child: LinearProgressIndicator(
            key: const Key('people.import.progress'),
            color: cp.colors.accent,
            backgroundColor: cp.colors.accentSoft,
            value: applying && progress != null && progress.total > 0
                ? progress.processed / progress.total
                : null,
          ),
        ),
        AdminNote(strings.needsConnection, icon: CpIcons.wifiOff),
      ]);
      return [wrap()];
    }
    if (job.status == ImportStatus.failed) {
      card.add(
        CpFieldError(
          strings.failed(job.error),
          key: const Key('people.import.failed'),
        ),
      );
      return [
        wrap(),
        CpButton.secondary(
          key: const Key('people.import.startOver'),
          label: strings.startOver,
          expand: true,
          onPressed: _startOver,
        ),
      ];
    }
    if (report != null) {
      card.add(
        Text(
          job.status == ImportStatus.done
              ? strings.imported(report.creates, report.updates)
              : strings.reportSummary(
                  report.total,
                  report.valid,
                  report.errorCount,
                ),
          key: const Key('people.import.summary'),
          style: cp.type.titleMedium.copyWith(color: cp.colors.text),
        ),
      );
      if (job.status == ImportStatus.checked) {
        card.add(
          Text(
            strings.willCreate(
              report.creates,
              report.updates,
              report.newGroups,
              words.other('group'),
            ),
            style: body,
          ),
        );
      }
      for (final id in report.unmappedRequiredFields) {
        card.add(
          Text(
            strings.requiredNotMapped(fieldsById[id]?.label ?? id),
            style: muted,
          ),
        );
      }
      out.add(wrap());
      if (report.errors.isNotEmpty) {
        out.addAll([
          CpSectionHeader(title: strings.errorsHeading),
          CpCard(
            padding: EdgeInsets.all(cp.space.lg),
            child: Column(
              key: const Key('people.import.errors'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.sm,
              children: [
                for (final e in report.errors)
                  CpFieldError(
                    strings.rowError(
                      e.row,
                      e.column,
                      strings.problemName(e.problem),
                    ),
                  ),
                if (report.errorCount > report.errors.length)
                  Text(
                    strings.moreErrors(
                      report.errorCount - report.errors.length,
                    ),
                    style: muted,
                  ),
              ],
            ),
          ),
        ]);
      }
      final missing = [
        for (final g in report.missingGroups)
          if (g.groupId != null && !job.cancelledGroupIds.contains(g.groupId))
            g,
      ];
      if (missing.isNotEmpty) {
        final canChoose = !_busy && job.status == ImportStatus.done;
        out.addAll([
          CpSectionHeader(title: strings.missingHeading(words.other('group'))),
          AdminNote(strings.missingHelp(words.other('group'))),
          CpCard(
            child: CpRowGroup(
              children: [
                for (final g in missing)
                  CpListRow(
                    key: Key('people.import.missing.${g.groupId}'),
                    leading: Checkbox(
                      value: _toCancel.contains(g.groupId),
                      activeColor: cp.colors.accent,
                      onChanged: canChoose
                          ? (on) => setState(
                              () => on!
                                  ? _toCancel.add(g.groupId!)
                                  : _toCancel.remove(g.groupId),
                            )
                          : null,
                    ),
                    title: g.name,
                    subtitle: strings.missingPeople(g.people),
                    trailing: const SizedBox.shrink(),
                    onTap: canChoose
                        ? () => setState(
                            () => _toCancel.contains(g.groupId)
                                ? _toCancel.remove(g.groupId)
                                : _toCancel.add(g.groupId!),
                          )
                        : null,
                  ),
              ],
            ),
          ),
          if (job.status == ImportStatus.done)
            CpButton.destructive(
              key: const Key('people.import.cancelMissing'),
              label: strings.cancelMissing,
              expand: true,
              onPressed: _busy || _toCancel.isEmpty
                  ? null
                  : () => _cancelMissing(job),
            ),
        ]);
      }
      if (job.status == ImportStatus.checked) {
        out.addAll([
          AdminNote(strings.applyHelp),
          CpButton(
            key: const Key('people.import.apply'),
            label: strings.apply,
            busy: _busy,
            expand: true,
            onPressed: report.valid > 0 ? () => _apply(job) : null,
          ),
        ]);
      }
    } else {
      out.add(wrap());
    }
    if (_errorText() case final error?) out.add(error);
    out.add(
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: cp.space.sm,
        runSpacing: cp.space.sm,
        children: [
          CpButton.text(
            key: const Key('people.import.startOver'),
            label: strings.startOver,
            onPressed: _busy ? null : _startOver,
          ),
          if (job.status == ImportStatus.done)
            CpButton(
              key: const Key('people.import.done'),
              label: strings.done,
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/dashboard/event/${widget.event.id}/people'),
            ),
        ],
      ),
    );
    return out;
  }
}

/// One column and what it holds.
class _ColumnMapping extends StatelessWidget {
  const _ColumnMapping({
    required this.index,
    required this.header,
    required this.sample,
    required this.value,
    required this.fields,
    required this.enabled,
    required this.onChanged,
  });

  final int index;
  final String header;
  final String sample;
  final String value;
  final List<CustomField> fields;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.imports;
    String label(String fieldId) =>
        fields.where((f) => f.id == fieldId).firstOrNull?.label ?? fieldId;
    final options = [...importTargets, for (final f in fields) 'field:${f.id}'];
    final current = options.contains(value) ? value : 'ignore';
    final name = header.isEmpty ? '#${index + 1}' : header;

    Future<void> pick() async {
      final picked = await showCpSheet<String>(
        context: context,
        title: name,
        builder: (sheet) => CpCard(
          child: CpRowGroup(
            children: [
              for (final t in options)
                CpListRow(
                  key: Key('people.import.map.$index.$t'),
                  title: strings.targetName(t, label),
                  selected: t == current,
                  trailing: t == current
                      ? Icon(
                          CpIcons.statusDone,
                          size: cp.sizes.iconMd,
                          color: cp.colors.accent,
                        )
                      : const SizedBox.shrink(),
                  onTap: () => Navigator.of(sheet).pop(t),
                ),
            ],
          ),
        ),
      );
      if (picked != null) onChanged(picked);
    }

    return CpSelectField(
      fieldKey: Key('people.import.map.$index'),
      label: name,
      help: sample.isEmpty ? null : sample,
      value: strings.targetName(current, label),
      onTap: enabled ? pick : null,
    );
  }
}
