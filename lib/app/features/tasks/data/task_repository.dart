import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:drift/drift.dart' show Value;
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/domain/repositories/i_task_repository.dart';

/// Callable signature for the `markTaskComplete` Cloud Function.
typedef MarkTaskCompleteCall =
    Future<void> Function({required String eventId, required String taskId});

class TaskRepository implements ITaskRepository {
  TaskRepository({
    required TasksDao tasksDao,
    required FirebaseFirestore firestore,
    MarkTaskCompleteCall? markTaskComplete,
  }) : _tasksDao = tasksDao,
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
  final FirebaseFirestore _firestore;
  final MarkTaskCompleteCall _markTaskComplete;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _firestoreSubs = {};

  CollectionReference<Map<String, dynamic>> _tasksRef(String eventId) =>
      _firestore.collection('events').doc(eventId).collection('tasks');

  @override
  Stream<List<TaskModel>> watchTasksByEventId(String eventId) {
    _ensureFirestoreMirror(eventId);
    return _tasksDao
        .watchTasksByEventId(eventId)
        .map((rows) => rows.map(_toDomain).toList());
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

  @override
  Future<List<TaskModel>> getTasksByEventId(String eventId) async {
    try {
      final rows = await _tasksDao.tasksByEventId(eventId);
      return rows.map(_toDomain).toList();
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
  );

  TaskModel _toDomain(Task row) => TaskModel(
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
  );

  TaskStatus _parseStatus(String? status) => switch (status) {
    'inProgress' => TaskStatus.inProgress,
    'done' => TaskStatus.done,
    _ => TaskStatus.todo,
  };
}
