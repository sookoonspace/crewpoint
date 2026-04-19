/// Attachment model for task files.
class TaskAttachment {
  const TaskAttachment({
    required this.id,
    required this.filePath,
    required this.fileName,
    this.fileType = AttachmentType.other,
  });

  final String id;
  final String filePath;
  final String fileName;
  final AttachmentType fileType;
}

enum AttachmentType { image, document, other }
