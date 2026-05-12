import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:drift/drift.dart' show Value;
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/task_checklist_items_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/domain/repositories/i_task_repository.dart';

/// Callable signature for the `markTaskComplete` Cloud Function.
typedef MarkTaskCompleteCall =
    Future<void> Function({required String eventId, required String taskId});

class TaskRepository implements ITaskRepository {
  TaskRepository({
    required TasksDao tasksDao,
    required TaskChecklistItemsDao checklistDao,
    required FirebaseFirestore firestore,
    MarkTaskCompleteCall? markTaskComplete,
  }) : _tasksDao = tasksDao,
       _checklistDao = checklistDao,
       _firestore = firestore,
       _markTaskComplete =
           markTaskComplete ??
           (({required eventId, required taskId}) async {
             final callable = FirebaseFunctions.instance.httpsCallable(
               'markTaskComplete',
             );
             await callable.call<Map<String, dynamic>>({
               'eventId': eventId,
               'taskId': taskId,
             });
           });

  final TasksDao _tasksDao;
  final TaskChecklistItemsDao _checklistDao;
  final FirebaseFirestore _firestore;
  final MarkTaskCompleteCall _markTaskComplete;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _firestoreSubs = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _checklistSubs = {};

  CollectionReference<Map<String, dynamic>> _checklistRef(
    String eventId,
    String taskId,
  ) => _firestore
      .collection('events')
      .doc(eventId)
      .collection('tasks')
      .doc(taskId)
      .collection('checklist');

  String _checklistKey(String eventId, String taskId) => '$eventId/$taskId';

  CollectionReference<Map<String, dynamic>> _tasksRef(String eventId) =>
      _firestore.collection('events').doc(eventId).collection('tasks');

  @override
  Stream<List<TaskModel>> watchTasksByEventId(String eventId) {
    _ensureFirestoreMirror(eventId);
    return _tasksDao.watchTasksByEventId(eventId).asyncMap(_hydrate);
  }

  /// Loads checklist rows for the supplied task rows in a single batched
  /// query and merges them into the returned [TaskModel]s. Fixes a
  /// pre-existing bug where the list path emitted `TaskModel.checklistItems`
  /// as an empty list (the checklist subcollection mirror lives on the
  /// detail page) — without this join the new progress bar on `TaskTile`
  /// would never render.
  Future<List<TaskModel>> _hydrate(List<Task> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r.id).toList(growable: false);
    final byTaskId = await _checklistDao.itemsByTaskIds(ids);
    return rows.map((row) {
      final items = byTaskId[row.id] ?? const <TaskChecklistItem>[];
      return _toDomain(row, items);
    }).toList();
  }

  void _ensureFirestoreMirror(String eventId) {
    if (_firestoreSubs.containsKey(eventId)) return;
    _firestoreSubs[eventId] = _tasksRef(eventId).snapshots().listen(
      (snap) {
        _mirrorSnapshot(eventId, snap).catchError((Object e, StackTrace st) {
          log('Mirror failed', error: e, stackTrace: st, name: 'tasks');
        });
      },
      onError: (Object e, StackTrace st) {
        log('Firestore stream error', error: e, stackTrace: st, name: 'tasks');
      },
    );
  }

  Future<void> _mirrorSnapshot(
    String eventId,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    final remoteIds = <String>{};
    for (final doc in snap.docs) {
      remoteIds.add(doc.id);
      final task = _fromFirestore(doc.id, eventId, doc.data());
      await _upsertDrift(task);
    }
    final localRows = await _tasksDao.tasksByEventId(eventId);
    for (final row in localRows) {
      if (!remoteIds.contains(row.id)) {
        await _tasksDao.deleteTaskById(row.id);
      }
    }
  }

  void disposeMirror(String eventId) {
    _firestoreSubs.remove(eventId)?.cancel();
  }

  /// Cancels all live Firestore subscriptions. Call from `ref.onDispose` or
  /// test teardown.
  Future<void> dispose() async {
    for (final sub in _firestoreSubs.values) {
      await sub.cancel();
    }
    _firestoreSubs.clear();
    for (final sub in _checklistSubs.values) {
      await sub.cancel();
    }
    _checklistSubs.clear();
  }

  // ===== Checklist =====

  Stream<List<ChecklistItem>> watchChecklist(String eventId, String taskId) {
    _ensureChecklistMirror(eventId, taskId);
    return _checklistDao
        .watchByTaskId(taskId)
        .map((rows) => rows.map(_checklistRowToDomain).toList());
  }

  void _ensureChecklistMirror(String eventId, String taskId) {
    final key = _checklistKey(eventId, taskId);
    if (_checklistSubs.containsKey(key)) return;
    _checklistSubs[key] = _checklistRef(eventId, taskId).snapshots().listen(
      (snap) {
        _mirrorChecklist(taskId, snap).catchError((Object e, StackTrace st) {
          log(
            'Checklist mirror failed',
            error: e,
            stackTrace: st,
            name: 'tasks',
          );
        });
      },
      onError: (Object e, StackTrace st) {
        log('Checklist stream error', error: e, stackTrace: st, name: 'tasks');
      },
    );
  }

  Future<void> _mirrorChecklist(
    String taskId,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    final remoteIds = <String>{};
    for (final doc in snap.docs) {
      remoteIds.add(doc.id);
      final item = _checklistFromFirestore(doc.id, doc.data());
      await _checklistDao.upsert(
        TaskChecklistItemsCompanion(
          id: Value(item.id),
          taskId: Value(taskId),
          content: Value(item.text),
          isCompleted: Value(item.isCompleted),
          sortOrder: Value(item.sortOrder),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
    final localRows = await _checklistDao.byTaskId(taskId);
    for (final row in localRows) {
      if (!remoteIds.contains(row.id)) {
        await _checklistDao.deleteById(row.id);
      }
    }
  }

  void disposeChecklistMirror(String eventId, String taskId) {
    _checklistSubs.remove(_checklistKey(eventId, taskId))?.cancel();
  }

  Future<bool> addChecklistItem({
    required String eventId,
    required String taskId,
    required String id,
    required String text,
    int sortOrder = 0,
  }) async {
    try {
      await _checklistRef(eventId, taskId).doc(id).set({
        'text': text,
        'isCompleted': false,
        'sortOrder': sortOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _checklistDao.upsert(
        TaskChecklistItemsCompanion.insert(
          id: id,
          taskId: taskId,
          content: text,
          sortOrder: Value(sortOrder),
        ),
      );
      return true;
    } catch (e, st) {
      log(
        'Failed to add checklist item',
        error: e,
        stackTrace: st,
        name: 'tasks',
      );
      return false;
    }
  }

  /// Toggle-only update — used by assignees who can only flip `isCompleted`.
  Future<bool> toggleChecklistItem({
    required String eventId,
    required String taskId,
    required String itemId,
    required bool isCompleted,
  }) async {
    try {
      await _checklistRef(eventId, taskId).doc(itemId).update({
        'isCompleted': isCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e, st) {
      log(
        'Failed to toggle checklist item',
        error: e,
        stackTrace: st,
        name: 'tasks',
      );
      return false;
    }
  }

  Future<bool> updateChecklistItem({
    required String eventId,
    required String taskId,
    required String itemId,
    String? text,
    bool? isCompleted,
  }) async {
    try {
      final patch = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (text != null) patch['text'] = text;
      if (isCompleted != null) patch['isCompleted'] = isCompleted;
      await _checklistRef(eventId, taskId).doc(itemId).update(patch);
      return true;
    } catch (e, st) {
      log(
        'Failed to update checklist item',
        error: e,
        stackTrace: st,
        name: 'tasks',
      );
      return false;
    }
  }

  Future<bool> deleteChecklistItem({
    required String eventId,
    required String taskId,
    required String itemId,
  }) async {
    try {
      await _checklistRef(eventId, taskId).doc(itemId).delete();
      await _checklistDao.deleteById(itemId);
      return true;
    } catch (e, st) {
      log(
        'Failed to delete checklist item',
        error: e,
        stackTrace: st,
        name: 'tasks',
      );
      return false;
    }
  }

  ChecklistItem _checklistRowToDomain(TaskChecklistItem row) => ChecklistItem(
    id: row.id,
    text: row.content,
    isCompleted: row.isCompleted,
    sortOrder: row.sortOrder,
  );

  ChecklistItem _checklistFromFirestore(String id, Map<String, dynamic> data) =>
      ChecklistItem(
        id: id,
        text: (data['text'] as String?) ?? '',
        isCompleted: (data['isCompleted'] as bool?) ?? false,
        sortOrder: (data['sortOrder'] as int?) ?? 0,
      );

  @override
  Future<List<TaskModel>> getTasksByEventId(String eventId) async {
    try {
      final rows = await _tasksDao.tasksByEventId(eventId);
      return _hydrate(rows);
    } catch (e, st) {
      log('Failed to get tasks', error: e, stackTrace: st, name: 'tasks');
      return [];
    }
  }

  @override
  Future<bool> createTask(TaskModel task) async {
    try {
      await _tasksRef(task.eventId).doc(task.id).set(_toFirestore(task));
      await _upsertDrift(task);
      return true;
    } catch (e, st) {
      log('Failed to create task', error: e, stackTrace: st, name: 'tasks');
      return false;
    }
  }

  /// Creates a task plus its checklist in a single atomic Firestore
  /// `WriteBatch`. Used by the Duplicate flow so a copied task's
  /// checklist either lands fully or not at all — no half-populated
  /// duplicates if the batch fails mid-way.
  Future<bool> createTaskWithChecklist(
    TaskModel task,
    List<ChecklistItem> items,
  ) async {
    try {
      final batch = _firestore.batch();
      batch.set(_tasksRef(task.eventId).doc(task.id), _toFirestore(task));
      for (final item in items) {
        batch.set(_checklistRef(task.eventId, task.id).doc(item.id), {
          'text': item.text,
          'isCompleted': item.isCompleted,
          'sortOrder': item.sortOrder,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Mirror to Drift after the batch commits.
      await _upsertDrift(task);
      for (final item in items) {
        await _checklistDao.upsert(
          TaskChecklistItemsCompanion.insert(
            id: item.id,
            taskId: task.id,
            content: item.text,
            isCompleted: Value(item.isCompleted),
            sortOrder: Value(item.sortOrder),
          ),
        );
      }
      return true;
    } catch (e, st) {
      log(
        'Failed to create task with checklist',
        error: e,
        stackTrace: st,
        name: 'tasks',
      );
      return false;
    }
  }

  @override
  Future<bool> updateTask(TaskModel task) async {
    try {
      await _tasksRef(task.eventId).doc(task.id).update({
        ..._toFirestore(task),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _upsertDrift(task);
      return true;
    } catch (e, st) {
      log('Failed to update task', error: e, stackTrace: st, name: 'tasks');
      return false;
    }
  }

  /// Transitions task status. Routes to [markTaskComplete] CF when going to
  /// `done`; direct Firestore write for other transitions.
  Future<bool> updateStatus({
    required String eventId,
    required String taskId,
    required TaskStatus newStatus,
  }) async {
    try {
      if (newStatus == TaskStatus.done) {
        await _markTaskComplete(eventId: eventId, taskId: taskId);
      } else {
        await _tasksRef(eventId).doc(taskId).update({
          'status': newStatus.name,
          'completedAt': null,
          'completedBy': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e, st) {
      log('Failed to update status', error: e, stackTrace: st, name: 'tasks');
      return false;
    }
  }

  @override
  Future<bool> deleteTask(String id) async {
    try {
      // Find eventId from local cache to delete remote doc
      final row = await _tasksDao.taskById(id);
      if (row != null) {
        await _tasksRef(row.eventId).doc(id).delete();
      }
      await _tasksDao.deleteTaskById(id);
      return true;
    } catch (e, st) {
      log('Failed to delete task', error: e, stackTrace: st, name: 'tasks');
      return false;
    }
  }

  Future<void> _upsertDrift(TaskModel task) async {
    await _tasksDao.insertOrReplace(
      TasksCompanion(
        id: Value(task.id),
        eventId: Value(task.eventId),
        title: Value(task.title),
        description: Value(task.description),
        assigneeId: Value(task.assigneeId),
        createdBy: Value(task.createdBy),
        status: Value(task.status.name),
        priority: Value(task.priority),
        dueDate: Value(task.dueDate),
        completedAt: Value(task.completedAt),
        completedBy: Value(task.completedBy),
        budgetEstimate: Value(task.budgetEstimate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Map<String, dynamic> _toFirestore(TaskModel task) => {
    'eventId': task.eventId,
    'title': task.title,
    'description': task.description,
    'assigneeId': task.assigneeId,
    'createdBy': task.createdBy,
    'status': task.status.name,
    'priority': task.priority,
    'dueDate': task.dueDate != null ? Timestamp.fromDate(task.dueDate!) : null,
    'completedAt': task.completedAt != null
        ? Timestamp.fromDate(task.completedAt!)
        : null,
    'completedBy': task.completedBy,
    'budgetEstimate': task.budgetEstimate,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  TaskModel _fromFirestore(
    String id,
    String eventId,
    Map<String, dynamic> data,
  ) => TaskModel(
    id: id,
    eventId: eventId,
    title: (data['title'] as String?) ?? '',
    description: data['description'] as String?,
    assigneeId: data['assigneeId'] as String?,
    createdBy: data['createdBy'] as String?,
    status: _parseStatus(data['status'] as String?),
    priority: (data['priority'] as int?) ?? 0,
    dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
    completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    completedBy: data['completedBy'] as String?,
    budgetEstimate: (data['budgetEstimate'] as num?)?.toDouble(),
  );

  TaskModel _toDomain(Task row, [List<TaskChecklistItem> items = const []]) =>
      TaskModel(
        id: row.id,
        eventId: row.eventId,
        title: row.title,
        description: row.description,
        assigneeId: row.assigneeId,
        createdBy: row.createdBy,
        status: _parseStatus(row.status),
        priority: row.priority,
        dueDate: row.dueDate,
        completedAt: row.completedAt,
        completedBy: row.completedBy,
        budgetEstimate: row.budgetEstimate,
        checklistItems: items.map(_checklistRowToDomain).toList(),
      );

  TaskStatus _parseStatus(String? status) => switch (status) {
    'inProgress' => TaskStatus.inProgress,
    'done' => TaskStatus.done,
    _ => TaskStatus.todo,
  };
}
