import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_export_pipeline.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_export_pipeline.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

import '../harness/recording_file_exporter.dart';

const _event = EventModel(
  id: 'evt-1',
  title: 'Tahoe Trip',
  creatorId: 'u1',
  memberIds: ['u1', 'u2'],
  currency: 'USD',
);

void main() {
  group('Budget export pipeline (PDF)', () {
    test('exports the expense PDF through IFileExporter with the canonical '
        'filename + mime', () async {
      final exporter = RecordingFileExporter();
      const expenses = [
        ExpenseModel(
          id: 'e1',
          eventId: 'evt-1',
          payerId: 'u1',
          amount: 30,
          description: 'Snacks',
        ),
        ExpenseModel(
          id: 'e2',
          eventId: 'evt-1',
          payerId: 'u2',
          amount: 60,
          description: 'Cabin night',
        ),
        ExpenseModel(
          id: 'e3',
          eventId: 'evt-1',
          payerId: 'u1',
          amount: 12,
          description: 'Park entry',
        ),
      ];

      await runExpenseExport(
        event: _event,
        expenses: expenses,
        memberNames: const {'u1': 'Alice', 'u2': 'Bob'},
        exporter: exporter,
        kind: ExpenseExportKind.pdf,
        now: DateTime.utc(2026, 4, 29),
      );

      final share = exporter.lastShare;
      expect(share, isNotNull);
      expect(share!.mimeType, equals('application/pdf'));
      expect(share.filename, equals('tahoe-trip-expenses-2026-04-29.pdf'));
      expect(share.bytes, isNotEmpty);
      // PDF magic header ensures the bytes are a real PDF, not a stub.
      expect(String.fromCharCodes(share.bytes.take(4)), equals('%PDF'));
    });
  });

  group('Budget export pipeline (CSV)', () {
    test(
      'exports the expense CSV through IFileExporter with text/csv mime',
      () async {
        final exporter = RecordingFileExporter();
        const expenses = [
          ExpenseModel(
            id: 'e1',
            eventId: 'evt-1',
            payerId: 'u1',
            amount: 30,
            description: 'Snacks',
          ),
        ];

        await runExpenseExport(
          event: _event,
          expenses: expenses,
          memberNames: const {'u1': 'Alice', 'u2': 'Bob'},
          exporter: exporter,
          kind: ExpenseExportKind.csv,
          now: DateTime.utc(2026, 4, 29),
        );

        final share = exporter.lastShare;
        expect(share, isNotNull);
        expect(share!.mimeType, equals('text/csv'));
        expect(share.filename, equals('tahoe-trip-expenses-2026-04-29.csv'));
        // CSV bytes should decode to UTF-8 text containing the header.
        final text = String.fromCharCodes(share.bytes);
        expect(text, startsWith('id,createdAt,payerId,'));
        expect(text, contains('Snacks'));
      },
    );
  });

  group('Tasks export pipeline (PDF)', () {
    test('exports the task PDF through IFileExporter with the canonical '
        'filename + mime', () async {
      final exporter = RecordingFileExporter();
      const tasks = [
        TaskModel(
          id: 't1',
          eventId: 'evt-1',
          title: 'Pack snacks',
          status: TaskStatus.todo,
        ),
        TaskModel(
          id: 't2',
          eventId: 'evt-1',
          title: 'Book bus',
          status: TaskStatus.done,
        ),
      ];

      await runTaskPdfExport(
        event: _event,
        tasks: tasks,
        memberNames: const {'u1': 'Alice'},
        exporter: exporter,
        now: DateTime.utc(2026, 4, 29),
      );

      final share = exporter.lastShare;
      expect(share, isNotNull);
      expect(share!.mimeType, equals('application/pdf'));
      expect(share.filename, equals('tahoe-trip-tasks-2026-04-29.pdf'));
      expect(String.fromCharCodes(share.bytes.take(4)), equals('%PDF'));
    });
  });
}
