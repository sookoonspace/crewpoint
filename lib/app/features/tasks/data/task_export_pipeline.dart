import 'package:crewpoint_app/app/core/services/file_export_service.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_pdf_builder.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// Builds the task PDF and routes it through the injected
/// [IFileExporter]. Pure orchestration — no Flutter / Riverpod imports.
Future<void> runTaskPdfExport({
  required EventModel event,
  required List<TaskModel> tasks,
  required Map<String, String> memberNames,
  required IFileExporter exporter,
  DateTime? now,
}) async {
  final filename = buildExportFilename(
    eventTitle: event.title,
    kind: 'tasks',
    extension: 'pdf',
    date: now ?? DateTime.now(),
  );
  final bytes = await buildTaskReport(
    event: event,
    tasks: tasks,
    memberNames: memberNames,
  );
  await exporter.share(
    bytes: bytes,
    filename: filename,
    mimeType: 'application/pdf',
  );
}
