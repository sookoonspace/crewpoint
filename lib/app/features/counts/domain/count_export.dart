import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/core/utils/csv_safety.dart';
import 'package:crewpoint_app/app/features/counts/domain/event_stats.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Counts kept on a date for suppliers (Req 54), from
/// `countFreezes/{id}`.
@immutable
class FrozenCounts {
  const FrozenCounts({
    required this.id,
    required this.stats,
    this.frozenAt,
    this.frozenBy,
    this.label,
  });

  factory FrozenCounts.fromFirestore(String id, Map<String, dynamic> data) {
    final at = data['frozenAt'];
    final label = data['label'];
    return FrozenCounts(
      id: id,
      stats: EventStats.fromFirestore(data),
      frozenAt: at is Timestamp ? at.toDate().toUtc() : null,
      frozenBy: data['frozenBy'] as String?,
      label: label is String && label.isNotEmpty ? label : null,
    );
  }

  final String id;
  final EventStats stats;
  final DateTime? frozenAt;
  final String? frozenBy;
  final String? label;
}

/// One count that changed since a freeze.
typedef CountChange = ({
  String where,
  String what,
  int before,
  int after,
  int difference,
});

/// The words counts and their changes are written with, from
/// `context.strings` in the app. English by default.
@immutable
class CountLabels {
  const CountLabels({
    this.wholeEvent = 'Whole event',
    this.total = 'Total',
    this.noAnswer = 'No answer',
    this.noCategory = 'No category',
    this.yes = 'Yes',
    this.no = 'No',
  });

  final String wholeEvent;
  final String total;
  final String noAnswer;
  final String noCategory;
  final String yes;
  final String no;
}

/// Fields whose answers are counted, in order, leaving out private ones
/// unless [includePrivate].
List<CustomField> _counted(List<CustomField> fields, bool includePrivate) => [
  for (final f in [...fields]..sort((a, b) => a.order.compareTo(b.order)))
    if ((f.type == FieldType.singleChoice ||
            f.type == FieldType.multiChoice ||
            f.type == FieldType.yesNo) &&
        (includePrivate || !f.isPrivate))
      f,
];

/// The columns after Total: each category, then each field's options and
/// "No answer", as (heading, read from a tally).
List<(String, int Function(CountTally))> _columns(
  EventModel event,
  EventStats stats,
  List<CustomField> fields,
  CountLabels labels,
) {
  final categories = categoriesOf(event.settings);
  final tallies = [stats.event, ...stats.sessions.values];
  final uncategorised = tallies.any((t) => t.byCategory.containsKey(noAnswer));
  return [
    for (final c in categories) (c.name, (t) => t.byCategory[c.id] ?? 0),
    if (uncategorised) (labels.noCategory, (t) => t.byCategory[noAnswer] ?? 0),
    for (final f in fields) ...[
      for (final o
          in f.type == FieldType.yesNo ? const ['yes', 'no'] : f.options)
        (
          '${f.label}: ${f.type == FieldType.yesNo ? (o == 'yes' ? labels.yes : labels.no) : o}',
          (t) => t.byField[f.id]?[o] ?? 0,
        ),
      (
        '${f.label}: ${labels.noAnswer}',
        (t) => t.byField[f.id]?[noAnswer] ?? 0,
      ),
    ],
  ];
}

String _toCsv(List<List<String>> rows) =>
    '${rows.map((row) => row.map((raw) {
      final cell = neutraliseCsvCell(raw);
      return RegExp(r'[",\r\n]').hasMatch(cell) ? '"${cell.replaceAll('"', '""')}"' : cell;
    }).join(',')).join('\r\n')}\r\n';

List<SessionModel> _inOrder(List<SessionModel> sessions, EventStats stats) => [
  for (final s in sessions)
    if (stats.sessions.containsKey(s.id)) s,
]..sort((a, b) => a.startAt.compareTo(b.startAt));

/// The counts as CSV for a caterer (Req 53): the whole event, then each
/// session in time order, by category and by each choice field. Private
/// fields are left out unless [includePrivate].
String countsCsv({
  required EventModel event,
  required EventStats stats,
  required List<SessionModel> sessions,
  required List<CustomField> fields,
  bool includePrivate = false,
  CountLabels labels = const CountLabels(),
}) {
  final columns = _columns(
    event,
    stats,
    _counted(fields, includePrivate),
    labels,
  );
  final time = DateFormat('yyyy-MM-dd HH:mm');
  List<String> row(String name, String when, CountTally t) => [
    name,
    when,
    '${t.total}',
    for (final (_, read) in columns) '${read(t)}',
  ];
  return _toCsv([
    ['Session', 'Starts', 'Total', for (final (h, _) in columns) h],
    row(labels.wholeEvent, '', stats.event),
    for (final s in _inOrder(sessions, stats))
      row(s.title, time.format(event.inZone(s.startAt)), stats.sessions[s.id]!),
  ]);
}

/// Every count that differs between a freeze and now (Req 54), for the
/// whole event then each session in time order. A session added since the
/// freeze counts from zero.
List<CountChange> countChanges({
  required EventStats frozen,
  required EventStats current,
  required List<SessionModel> sessions,
  required List<CustomField> fields,
  required EventModel event,
  bool includePrivate = false,
  CountLabels labels = const CountLabels(),
}) {
  final counted = _counted(fields, includePrivate);
  final columns = [
    ..._columns(event, frozen, counted, labels),
    ..._columns(event, current, counted, labels),
  ];
  final seen = <String>{};
  final unique = [
    for (final c in columns)
      if (seen.add(c.$1)) c,
  ];
  final changes = <CountChange>[];
  void compare(String where, CountTally before, CountTally after) {
    for (final (what, read) in [
      (labels.total, (CountTally t) => t.total),
      ...unique,
    ]) {
      final b = read(before);
      final a = read(after);
      if (a != b) {
        changes.add((
          where: where,
          what: what,
          before: b,
          after: a,
          difference: a - b,
        ));
      }
    }
  }

  compare(labels.wholeEvent, frozen.event, current.event);
  final all = {...frozen.sessions.keys, ...current.sessions.keys};
  for (final s in [
    ...sessions,
  ]..sort((a, b) => a.startAt.compareTo(b.startAt))) {
    if (!all.contains(s.id)) continue;
    compare(
      s.title,
      frozen.sessions[s.id] ?? const CountTally(),
      current.sessions[s.id] ?? const CountTally(),
    );
  }
  return changes;
}

/// Changes since a freeze as CSV, for the caterer.
String changesCsv(List<CountChange> changes) => _toCsv([
  ['Session', 'Count', 'Frozen', 'Now', 'Change'],
  for (final c in changes)
    [
      c.where,
      c.what,
      '${c.before}',
      '${c.after}',
      c.difference > 0 ? '+${c.difference}' : '${c.difference}',
    ],
]);
