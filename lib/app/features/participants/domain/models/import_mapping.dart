import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';

/// The start of an export, enough to map its columns (Req 44). Reads CSV the
/// same way as `functions/src/imports/csv.ts`; the server checks the rows.
class CsvPreview {
  const CsvPreview({
    required this.header,
    required this.rows,
    required this.rowCount,
  });

  final List<String> header;

  /// The first few rows, to show beside the mapping.
  final List<List<String>> rows;

  /// Rows after the header.
  final int rowCount;
}

/// Reads [text] as CSV (RFC 4180). Throws [FormatException] when it is empty
/// or a quote is never closed.
CsvPreview previewCsv(String text, {int rows = 3}) {
  final all = _parse(text);
  if (all.isEmpty) throw const FormatException('The file is empty.');
  return CsvPreview(
    header: all.first,
    rows: all.skip(1).take(rows).toList(),
    rowCount: all.length - 1,
  );
}

List<List<String>> _parse(String text) {
  final input = text.startsWith('﻿') ? text.substring(1) : text;
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var cellStarted = false;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
    cellStarted = false;
  }

  void endRow() {
    endCell();
    if (row.length > 1 || row.first.isNotEmpty) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
      continue;
    }
    if (ch == '"' && !cellStarted && cell.isEmpty) {
      quoted = true;
      cellStarted = true;
    } else if (ch == ',') {
      endCell();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      endRow();
    } else {
      cell.write(ch);
      cellStarted = true;
    }
  }
  if (quoted) throw const FormatException('A quoted cell is never closed.');
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// The column targets the server takes, as in `functions/src/imports/plan.ts`.
const importTargets = [
  'ignore',
  'name',
  'group',
  'externalId',
  'birthDate',
  'age',
  'isChild',
  'category',
  'email',
];

String _norm(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-.]+'), ' ');

const _guesses = <String, List<String>>{
  'name': ['name', 'full name', 'participant', 'attendee', 'guest name'],
  'group': ['group', 'household', 'team', 'party'],
  'externalId': [
    'id',
    'external id',
    'registration id',
    'reg id',
    'registration',
    'ticket id',
  ],
  'birthDate': ['date of birth', 'birth date', 'birthdate', 'dob', 'born'],
  'age': ['age'],
  'email': ['email', 'e mail', 'email address'],
  'category': ['category', 'type'],
  'isChild': ['child', 'is child', 'kid'],
};

/// What a column headed [header] most likely holds. [words] are the
/// event's own names for concepts, such as its word for a group, so an
/// export using them maps without help.
String guessTarget(
  String header,
  List<CustomField> fields, {
  Map<String, List<String>> words = const {},
}) {
  final h = _norm(header);
  for (final entry in _guesses.entries) {
    if (entry.value.contains(h)) return entry.key;
    if ((words[entry.key] ?? const []).map(_norm).contains(h)) {
      return entry.key;
    }
  }
  for (final f in fields) {
    if (_norm(f.label) == h) return 'field:${f.id}';
  }
  return 'ignore';
}

/// A guess for every column, each target used once.
List<String> guessTargets(
  List<String> header,
  List<CustomField> fields, {
  Map<String, List<String>> words = const {},
}) {
  final used = <String>{};
  return [
    for (final h in header)
      switch (guessTarget(h, fields, words: words)) {
        final t when t != 'ignore' && used.add(t) => t,
        _ => 'ignore',
      },
  ];
}

enum MappingProblem { nameNotMapped }

MappingProblem? mappingProblem(List<String> targets) =>
    targets.contains('name') ? null : MappingProblem.nameNotMapped;
