import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/mirror_syncs_dao.dart';
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
    MirrorSyncsDao? syncs,
  }) : _syncs = syncs,
       _tasksDao = tasksDao,
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
  final MirrorSyncsDao? _syncs;

  /// The key under which this mirror records when it last synced (Req 74).
  static String mirrorKey(String eventId) => 'tasks/$eventId';
  final TaskChecklistItemsDao _checklistDao;
  final FirebaseFirestore _firestore;
  final MarkTaskCompleteCall _markTaskComplete;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _firestoreSubs = {};

  /// The assignee each event's mirror is limited to, or null for all tasks.
  final Map<String, String?> _mirrorScopes = {};
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

  /// The tasks a reader may list. A Vendor or Observer must filter on
  /// `assigneeId`, because rules refuse a query that could return a task
  /// they cannot read (Req 32).
  Query<Map<String, dynamic>> _tasksQuery(String eventId, String? assigneeId) =>
      assigneeId == null
      ? _tasksRef(eventId)
      : _tasksRef(eventId).where('assigneeId', isEqualTo: assigneeId);

  @override
  Stream<List<TaskModel>> watchTasksByEventId(
    String eventId, {
    String? assigneeId,
  }) {
    // Web has no Drift persistence (Wasm is in-memory) and the empty-table
    // watch on Wasm Drift does not reliably emit its first frame. Match
    // `EventRepository.watchEventsForUser`'s web fork: read straight from
    // Firestore. `checklistItems` stays empty on the tile-list path here —
    // same as the pre-`_hydrate` legacy behavior. The detail-page subscribes
    // to the per-task checklist subcollection separately.
    if (kIsWeb) {
      return _tasksQuery(eventId, assigneeId).snapshots().map(
        (snap) => snap.docs
            .map((doc) => _fromFirestore(doc.id, eventId, doc.data()))
            .toList(),
      );
    }
    _ensureFirestoreMirror(eventId, assigneeId);
    return _tasksDao
        .watchTasksByEventId(eventId, assigneeId: assigneeId)
        .asyncMap(_hydrate);
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

  /// Starts the event's mirror, or restarts it when the reader's access
  /// changed. A narrower mirror deletes the rows it no longer returns.
  void _ensureFirestoreMirror(String eventId, String? assigneeId) {
    if (_firestoreSubs.containsKey(eventId) &&
        _mirrorScopes[eventId] == assigneeId) {
      return;
    }
    _firestoreSubs.remove(eventId)?.cancel();
    _mirrorScopes[eventId] = assigneeId;
    var applied = false;
    _firestoreSubs[eventId] = _tasksQuery(eventId, assigneeId)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snap) async {
            try {
              // A change only to whether it came from the cache moves no rows.
              if (!applied || snap.docChanges.isNotEmpty) {
                applied = true;
                await _mirrorSnapshot(eventId, snap);
              }
              await _syncs?.record(
                mirrorKey(eventId),
                fromCache: snap.metadata.isFromCache,
              );
            } catch (e, st) {
              log('Mirror failed', error: e, stackTrace: st, name: 'tasks');
            }
          },
          onError: (Object e, StackTrace st) {
            log(
              'Firestore stream error',
              error: e,
              stackTrace: st,
              name: 'tasks',
            );
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
    _mirrorScopes.remove(eventId);
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
      // `await` is load-bearing: without it the future escapes the try
      // block and a rejection from _hydrate would bypass the catch below
      // instead of degrading to an empty list.
      return await _hydrate(rows);
    } catch (e, st) {
      log('Failed to get tasks', error: e, stackTrace: st, name: 'tasks');
      return [];
    }
  }

  @override
  Future<bool> createTask(TaskModel task) async {
    try {
      final batch = _firestore.batch();
      batch.set(_tasksRef(task.eventId).doc(task.id), _toFirestore(task));
      _writeBudget(batch, task, editedBy: task.createdBy);
      await batch.commit();
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
      _writeBudget(batch, task, editedBy: task.createdBy);
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
  Future<bool> updateTask(TaskModel task, {String? budgetEditedBy}) async {
    try {
      // Status changes go through [updateStatus]. Rules deny writing completion
      // fields, and re-sending a server timestamp could not match it exactly.
      final fields = _toFirestore(task)
        ..remove('status')
        ..remove('completedAt')
        ..remove('completedBy');
      final batch = _firestore.batch();
      batch.update(_tasksRef(task.eventId).doc(task.id), fields);
      if (budgetEditedBy != null) {
        _writeBudget(batch, task, editedBy: budgetEditedBy, clear: true);
      }
      await batch.commit();
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

  CollectionReference<Map<String, dynamic>> _budgetsRef(String eventId) =>
      _firestore.collection('events').doc(eventId).collection('taskBudgets');

  /// A task's budget figure lives in `taskBudgets/{taskId}`, which needs
  /// `budget.read` to read and `budget.edit` to write (Req 36). An empty
  /// figure writes nothing, or with [clear] removes the one there.
  void _writeBudget(
    WriteBatch batch,
    TaskModel task, {
    required String? editedBy,
    bool clear = false,
  }) {
    final ref = _budgetsRef(task.eventId).doc(task.id);
    final estimate = task.budgetEstimate;
    if (estimate == null) {
      if (clear) batch.delete(ref);
      return;
    }
    batch.set(ref, {
      'estimate': estimate,
      'updatedBy': editedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Budget figures by task ID, read straight from Firestore so they never
  /// sit in the local mirror. Only for people holding `budget.read`.
  @override
  Stream<Map<String, double>> watchBudgets(String eventId) =>
      _budgetsRef(eventId).snapshots().map(
        (snapshot) => {
          for (final doc in snapshot.docs)
            if (doc.data()['estimate'] is num)
              doc.id: (doc.data()['estimate'] as num).toDouble(),
        },
      );

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
        // Budget figures stay out of the local mirror (Req 36).
        budgetEstimate: const Value(null),
        crewId: Value(task.crewId),
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
    // Only markTaskComplete sets these, so a client write leaves them empty.
    'completedAt': null,
    'completedBy': null,
    'crewId': task.crewId,
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
    crewId: data['crewId'] as String?,
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
        crewId: row.crewId,
        checklistItems: items.map(_checklistRowToDomain).toList(),
      );

  TaskStatus _parseStatus(String? status) => switch (status) {
    'inProgress' => TaskStatus.inProgress,
    'done' => TaskStatus.done,
    _ => TaskStatus.todo,
  };
}
