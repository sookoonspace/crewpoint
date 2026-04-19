/// Domain model for a task within an event.
class TaskModel {
  const TaskModel({
    required this.id,
    required this.eventId,
    required this.title,
    this.description,
    this.assigneeId,
    this.status = TaskStatus.todo,
    this.priority = 0,
    this.dueDate,
    this.checklistItems = const [],
  });

  final String id;
  final String eventId;
  final String title;
  final String? description;
  final String? assigneeId;
  final TaskStatus status;
  final int priority;
  final DateTime? dueDate;
  final List<ChecklistItem> checklistItems;

  TaskModel copyWith({
    String? title,
    String? description,
    String? assigneeId,
    TaskStatus? status,
    int? priority,
    DateTime? dueDate,
    List<ChecklistItem>? checklistItems,
  }) {
    return TaskModel(
      id: id,
      eventId: eventId,
      title: title ?? this.title,
      description: description ?? this.description,
      assigneeId: assigneeId ?? this.assigneeId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      checklistItems: checklistItems ?? this.checklistItems,
    );
  }
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
