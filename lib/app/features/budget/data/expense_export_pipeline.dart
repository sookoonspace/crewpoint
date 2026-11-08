import 'dart:typed_data';

import 'package:crewpoint_app/app/core/services/file_export_service.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_csv_builder.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_pdf_builder.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Builds the PDF report; [buildExpenseReport] outside tests.
typedef ExpenseReportBuilder =
    Future<Uint8List> Function({
      required EventModel event,
      required List<ExpenseModel> expenses,
      required Map<String, String> memberNames,
      required BalanceLedger ledger,
    });

/// Which kind of expense export the pipeline should produce.
enum ExpenseExportKind { pdf, csv }

/// Builds the right bytes for [kind], computes the slugified filename,
/// and routes everything through the injected [IFileExporter]. Pure
/// orchestration — no Flutter / Riverpod imports — so widget and journey
/// tests can drive this with a recording fake.
Future<void> runExpenseExport({
  required EventModel event,
  required List<ExpenseModel> expenses,
  required Map<String, String> memberNames,
  required IFileExporter exporter,
  required ExpenseExportKind kind,
  DateTime? now,
  BalanceLedger? ledger,
  ExpenseReportBuilder buildReport = buildExpenseReport,
}) async {
  final filename = buildExportFilename(
    eventTitle: event.title,
    kind: 'expenses',
    extension: kind == ExpenseExportKind.pdf ? 'pdf' : 'csv',
    date: now ?? DateTime.now(),
  );

  switch (kind) {
    case ExpenseExportKind.pdf:
      // [ledger] is given for someone who may not read every expense: their
      // own balance from the server, not one worked out from what they see
      // (Req 38f). [expenses] already holds only what they may read.
      final bytes = await buildReport(
        event: event,
        expenses: expenses,
        memberNames: memberNames,
        ledger:
            ledger ??
            BalanceLedger.calculate(
              expenses: expenses,
              memberIds: event.memberIds,
            ),
      );
      await exporter.share(
        bytes: bytes,
        filename: filename,
        mimeType: 'application/pdf',
      );
    case ExpenseExportKind.csv:
      final csv = buildExpenseCsv(
        event: event,
        expenses: expenses,
        memberNames: memberNames,
      );
      await exporter.share(
        bytes: Uint8List.fromList(csv.codeUnits),
        filename: filename,
        mimeType: 'text/csv',
      );
  }
}
