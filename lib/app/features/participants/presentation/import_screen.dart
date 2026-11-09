import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/file_picker_service.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
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
      child: Scaffold(
        appBar: AppBar(title: Text(title), elevation: 0),
        body: body,
      ),
    );

    if (!event.can(me, 'participants.import')) {
      return scaffold(const NoAccessView());
    }
    final fields =
        ref.watch(eventFieldsProvider(event.id)).value ?? const <CustomField>[];
    final fieldsById = {for (final f in fields) f.id: f};
    final theme = Theme.of(context);

    final List<Widget> children;
    final jobId = _jobId;
    if (jobId != null) {
      children = _jobView(jobId, strings, fieldsById, theme);
    } else {
      children = [
        Text(strings.intro, style: theme.textTheme.bodyMedium),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            const Icon(AppIcons.wifiOff, size: 20),
            Expanded(
              child: Text(
                strings.needsConnection,
                key: const Key('people.import.online'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        if (_preview == null) ..._recent(strings, theme),
        OutlinedButton.icon(
          key: const Key('people.import.pick'),
          onPressed: _busy ? null : () => _pick(fields),
          icon: const Icon(AppIcons.importFile),
          label: Text(_file == null ? strings.pick : strings.pickAnother),
        ),
        if (_preview case final preview?) ...[
          Text(
            strings.fileSummary(_file!.name, preview.rowCount),
            key: const Key('people.import.file'),
            style: theme.textTheme.titleSmall,
          ),
          Text(strings.mappingHeading, style: theme.textTheme.titleMedium),
          Text(strings.mappingHelp, style: theme.textTheme.bodySmall),
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
            Text(
              strings.nameNotMapped,
              key: const Key('people.import.nameNotMapped'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          PrimaryButton(
            key: const Key('people.import.check'),
            label: strings.check,
            isLoading: _busy,
            onPressed: mappingProblem(_targets) == null ? _check : null,
          ),
        ],
        if (_error != null) _errorText(theme),
      ];
    }

    return scaffold(
      ListView(
        key: const Key('people.import.body'),
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.lg,
        ),
        children: [
          ContentMaxWidth(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.md,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorText(ThemeData theme) => Text(
    _error!,
    key: const Key('people.import.error'),
    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
  );

  List<Widget> _recent(ImportStrings strings, ThemeData theme) {
    final recent = ref.watch(recentImportsProvider(widget.event.id)).value;
    if (recent == null || recent.isEmpty) return const [];
    return [
      Text(strings.recentHeading, style: theme.textTheme.titleSmall),
      for (final job in recent)
        ListTile(
          key: Key('people.import.job.${job.id}'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.members),
          title: Text(job.fileName),
          subtitle: Text(strings.statusName(job.status.name)),
          onTap: () => setState(() => _jobId = job.id),
        ),
    ];
  }

  List<Widget> _jobView(
    String jobId,
    ImportStrings strings,
    Map<String, CustomField> fieldsById,
    ThemeData theme,
  ) {
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
        const Center(
          child: CircularProgressIndicator(key: Key('people.import.loading')),
        ),
      ];
    }
    final words = widget.event.words;
    final report = job.report;
    final progress = job.progress;
    final out = <Widget>[Text(job.fileName, style: theme.textTheme.titleSmall)];
    if (job.isWorking) {
      final applying = job.mode == 'apply';
      out.addAll([
        Text(
          applying
              ? (progress == null
                    ? strings.queued
                    : strings.progress(progress.processed, progress.total))
              : strings.checking,
          key: const Key('people.import.status'),
        ),
        LinearProgressIndicator(
          key: const Key('people.import.progress'),
          value: applying && progress != null && progress.total > 0
              ? progress.processed / progress.total
              : null,
        ),
        Text(strings.needsConnection, style: theme.textTheme.bodySmall),
      ]);
      return out;
    }
    if (job.status == ImportStatus.failed) {
      out.addAll([
        Text(
          strings.failed(job.error),
          key: const Key('people.import.failed'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        OutlinedButton(
          key: const Key('people.import.startOver'),
          onPressed: _startOver,
          child: Text(strings.startOver),
        ),
      ]);
      return out;
    }
    if (report != null) {
      out.add(
        Text(
          job.status == ImportStatus.done
              ? strings.imported(report.creates, report.updates)
              : strings.reportSummary(
                  report.total,
                  report.valid,
                  report.errorCount,
                ),
          key: const Key('people.import.summary'),
          style: theme.textTheme.titleMedium,
        ),
      );
      if (job.status == ImportStatus.checked) {
        out.add(
          Text(
            strings.willCreate(
              report.creates,
              report.updates,
              report.newGroups,
              words.other('group'),
            ),
          ),
        );
      }
      for (final id in report.unmappedRequiredFields) {
        out.add(
          Text(
            strings.requiredNotMapped(fieldsById[id]?.label ?? id),
            style: theme.textTheme.bodySmall,
          ),
        );
      }
      if (report.errors.isNotEmpty) {
        out.addAll([
          Text(strings.errorsHeading, style: theme.textTheme.titleSmall),
          Column(
            key: const Key('people.import.errors'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in report.errors)
                Text(
                  strings.rowError(
                    e.row,
                    e.column,
                    strings.problemName(e.problem),
                  ),
                ),
              if (report.errorCount > report.errors.length)
                Text(
                  strings.moreErrors(report.errorCount - report.errors.length),
                ),
            ],
          ),
        ]);
      }
      final missing = [
        for (final g in report.missingGroups)
          if (g.groupId != null && !job.cancelledGroupIds.contains(g.groupId))
            g,
      ];
      if (missing.isNotEmpty) {
        out.addAll([
          Text(
            strings.missingHeading(words.other('group')),
            style: theme.textTheme.titleSmall,
          ),
          Text(
            strings.missingHelp(words.other('group')),
            style: theme.textTheme.bodySmall,
          ),
          for (final g in missing)
            CheckboxListTile(
              key: Key('people.import.missing.${g.groupId}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(g.name),
              subtitle: Text(strings.missingPeople(g.people)),
              value: _toCancel.contains(g.groupId),
              onChanged: _busy || job.status != ImportStatus.done
                  ? null
                  : (on) => setState(
                      () => on!
                          ? _toCancel.add(g.groupId!)
                          : _toCancel.remove(g.groupId),
                    ),
            ),
          if (job.status == ImportStatus.done)
            OutlinedButton(
              key: const Key('people.import.cancelMissing'),
              onPressed: _busy || _toCancel.isEmpty
                  ? null
                  : () => _cancelMissing(job),
              child: Text(strings.cancelMissing),
            ),
        ]);
      }
      if (job.status == ImportStatus.checked) {
        out.addAll([
          Text(strings.applyHelp, style: theme.textTheme.bodySmall),
          PrimaryButton(
            key: const Key('people.import.apply'),
            label: strings.apply,
            isLoading: _busy,
            onPressed: report.valid > 0 ? () => _apply(job) : null,
          ),
        ]);
      }
    }
    if (_error != null) out.add(_errorText(theme));
    out.add(
      OverflowBar(
        alignment: MainAxisAlignment.spaceBetween,
        overflowAlignment: OverflowBarAlignment.end,
        children: [
          TextButton(
            key: const Key('people.import.startOver'),
            onPressed: _busy ? null : _startOver,
            child: Text(strings.startOver),
          ),
          if (job.status == ImportStatus.done)
            FilledButton(
              key: const Key('people.import.done'),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/dashboard/event/${widget.event.id}/people'),
              child: Text(strings.done),
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
    final strings = context.strings.imports;
    String label(String fieldId) =>
        fields.where((f) => f.id == fieldId).firstOrNull?.label ?? fieldId;
    final options = [...importTargets, for (final f in fields) 'field:${f.id}'];
    return DropdownButtonFormField<String>(
      key: Key('people.import.map.$index'),
      isExpanded: true,
      initialValue: options.contains(value) ? value : 'ignore',
      decoration: InputDecoration(
        labelText: header.isEmpty ? '#${index + 1}' : header,
        helperText: sample.isEmpty ? null : sample,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final t in options)
          DropdownMenuItem(value: t, child: Text(strings.targetName(t, label))),
      ],
      onChanged: enabled ? (t) => onChanged(t!) : null,
    );
  }
}
