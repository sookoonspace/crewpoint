/// Where an import job is (Req 44a, 75), as `onImportQueued` writes it.
enum ImportStatus { queued, running, checked, done, failed }

/// One row the server could not import.
class ImportRowError {
  const ImportRowError({
    required this.row,
    required this.column,
    required this.problem,
  });

  /// 1-based, counting the header as row 1, as a spreadsheet shows it.
  final int row;
  final String column;

  /// `required`, `unknownAge`, `duplicateEmail`, `badEmail`, `notAnOption`,
  /// `wrongType`, `tooLong`, `duplicateRow` or `unknownCategory`.
  final String problem;
}

/// An imported group with nobody in a re-import (Req 45).
class MissingGroup {
  const MissingGroup({
    required this.groupId,
    required this.name,
    required this.people,
  });

  final String? groupId;
  final String name;
  final int people;
}

/// What a check or an import found.
class ImportReport {
  const ImportReport({
    required this.total,
    required this.valid,
    required this.creates,
    required this.updates,
    required this.newGroups,
    required this.errorCount,
    this.errors = const [],
    this.mappingProblems = const [],
    this.missingGroups = const [],
  });

  factory ImportReport.fromMap(Map<String, dynamic> m) {
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    return ImportReport(
      total: n('total'),
      valid: n('valid'),
      creates: n('creates'),
      updates: n('updates'),
      newGroups: n('newGroups'),
      errorCount: n('errorCount'),
      errors: [
        for (final e in (m['errors'] as List?) ?? const [])
          if (e is Map)
            ImportRowError(
              row: (e['row'] as num?)?.toInt() ?? 0,
              column: e['column'] as String? ?? '',
              problem: e['problem'] as String? ?? '',
            ),
      ],
      mappingProblems: [
        for (final p in (m['mappingProblems'] as List?) ?? const [])
          if (p is String) p,
      ],
      missingGroups: [
        for (final g in (m['missingGroups'] as List?) ?? const [])
          if (g is Map)
            MissingGroup(
              groupId: g['groupId'] as String?,
              name: g['name'] as String? ?? '',
              people: ((g['participantIds'] as List?) ?? const []).length,
            ),
      ],
    );
  }

  final int total;
  final int valid;
  final int creates;
  final int updates;
  final int newGroups;
  final int errorCount;

  /// The first errors, up to 500.
  final List<ImportRowError> errors;
  final List<String> mappingProblems;
  final List<MissingGroup> missingGroups;

  /// Required custom fields no column was mapped to.
  List<String> get unmappedRequiredFields => [
    for (final p in mappingProblems)
      if (p.startsWith('requiredFieldNotMapped:'))
        p.substring('requiredFieldNotMapped:'.length),
  ];
}

/// `events/{eventId}/imports/{id}`.
class ImportJob {
  const ImportJob({
    required this.id,
    required this.status,
    this.mode = 'dryRun',
    this.fileName = '',
    this.header = const [],
    this.targets = const [],
    this.report,
    this.progress,
    this.error,
    this.cancelledGroupIds = const [],
    this.createdAt,
  });

  factory ImportJob.fromFirestore(String id, Map<String, dynamic> d) {
    List<String> strings(Object? v) => [
      for (final x in (v as List?) ?? const [])
        if (x is String) x,
    ];
    final progress = d['progress'];
    final created = d['createdAt'];
    return ImportJob(
      id: id,
      status: ImportStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => ImportStatus.queued,
      ),
      mode: d['mode'] as String? ?? 'dryRun',
      fileName: d['fileName'] as String? ?? '',
      header: strings(d['header']),
      targets: strings(d['targets']),
      report: d['report'] is Map
          ? ImportReport.fromMap((d['report'] as Map).cast<String, dynamic>())
          : null,
      progress: progress is Map
          ? (
              processed: (progress['processed'] as num?)?.toInt() ?? 0,
              total: (progress['total'] as num?)?.toInt() ?? 0,
            )
          : null,
      error: d['error'] as String?,
      cancelledGroupIds: strings(d['cancelledGroupIds']),
      createdAt: created is DateTime
          ? created
          : (created as dynamic)?.toDate() as DateTime?,
    );
  }

  final String id;
  final ImportStatus status;
  final String mode;
  final String fileName;
  final List<String> header;
  final List<String> targets;
  final ImportReport? report;
  final ({int processed, int total})? progress;

  /// Why the job failed, such as `unreadable`.
  final String? error;
  final List<String> cancelledGroupIds;
  final DateTime? createdAt;

  bool get isWorking =>
      status == ImportStatus.queued || status == ImportStatus.running;
}
