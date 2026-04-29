import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/file_export_service.dart';

void main() {
  test('slugifies the event title and appends kind + ISO date', () {
    final name = buildExportFilename(
      eventTitle: 'Weekend  Trip — Tahoe!',
      kind: 'expenses',
      extension: 'pdf',
      date: DateTime.utc(2026, 4, 29),
    );
    expect(name, equals('weekend-trip-tahoe-expenses-2026-04-29.pdf'));
  });

  test('falls back to "report" when the slug would otherwise be empty', () {
    final name = buildExportFilename(
      eventTitle: '!!!',
      kind: 'tasks',
      extension: 'pdf',
      date: DateTime.utc(2026, 4, 29),
    );
    expect(name, equals('report-tasks-2026-04-29.pdf'));
  });

  test('honors the requested extension', () {
    final name = buildExportFilename(
      eventTitle: 'Trip',
      kind: 'expenses',
      extension: 'csv',
      date: DateTime.utc(2026, 4, 29),
    );
    expect(name, endsWith('.csv'));
  });
}
