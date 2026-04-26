/// Domain model for a task within an event.
class TaskModel {
  const TaskModel({
    required this.id,
    required this.eventId,
    required this.title,
    this.description,
    this.assigneeId,
    this.createdBy,
    this.status = TaskStatus.todo,
    this.priority = 0,
    this.dueDate,
    this.completedAt,
    this.completedBy,
    this.checklistItems = const [],
  });

  final String id;
  final String eventId;
  final String title;
  final String? description;
  final String? assigneeId;
  final String? createdBy;
  final TaskStatus status;
  final int priority;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? completedBy;
  final List<ChecklistItem> checklistItems;

  TaskModel copyWith({
    String? title,
    String? description,
    String? assigneeId,
    String? createdBy,
    TaskStatus? status,
    int? priority,
    DateTime? dueDate,
    DateTime? completedAt,
    String? completedBy,
    List<ChecklistItem>? checklistItems,
  }) {
    return TaskModel(
      id: id,
      eventId: eventId,
      title: title ?? this.title,
      description: description ?? this.description,
      assigneeId: assigneeId ?? this.assigneeId,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      checklistItems: checklistItems ?? this.checklistItems,
    );
  }

  /// RBAC: caller may transition `status` if owner, admin, or assignee.
  bool canChangeStatus({
    required bool isOwner,
    required bool isAdmin,
    required String? currentUserId,
  }) =>
      isOwner ||
      isAdmin ||
      (currentUserId != null && assigneeId == currentUserId);

  /// RBAC: caller may edit other fields or delete.
  bool canEditOrDelete({
    required bool isOwner,
    required bool isAdmin,
    required String? currentUserId,
  }) =>
      isOwner ||
      isAdmin ||
      (currentUserId != null && createdBy == currentUserId);
}

enum TaskStatus {
  todo,
  inProgress,
  done;

  String get label => switch (this) {
    TaskStatus.todo => 'To Do',
    TaskStatus.inProgress => 'In Progress',
    TaskStatus.done => 'Done',
  };
}

class ChecklistItem {
  const ChecklistItem({required this.text, this.isCompleted = false});

  final String text;
  final bool isCompleted;

  ChecklistItem copyWith({bool? isCompleted}) =>
      ChecklistItem(text: text, isCompleted: isCompleted ?? this.isCompleted);
}
