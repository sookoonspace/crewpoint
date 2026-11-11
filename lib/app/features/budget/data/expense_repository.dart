import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crewpoint_app/app/core/database/app_database.dart' as db;
import 'package:crewpoint_app/app/core/database/app_database.dart'
    show ExpensesCompanion, ExpenseSplitsCompanion;
import 'package:crewpoint_app/app/core/database/daos/expense_splits_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expenses_dao.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/repositories/i_expense_repository.dart';

class ExpenseRepository implements IExpenseRepository {
  ExpenseRepository({
    required ExpensesDao expensesDao,
    required ExpenseSplitsDao splitsDao,
    required FirebaseFirestore firestore,
    required SaveExpenseCall saveExpenseCall,
    required RecordSettlementCall recordSettlementCall,
    IImageService? imageService,
  }) : _expensesDao = expensesDao,
       _splitsDao = splitsDao,
       _firestore = firestore,
       _saveExpenseCall = saveExpenseCall,
       _recordSettlementCall = recordSettlementCall,
       _imageService = imageService;

  final ExpensesDao _expensesDao;
  final ExpenseSplitsDao _splitsDao;
  final FirebaseFirestore _firestore;
  final SaveExpenseCall _saveExpenseCall;
  final RecordSettlementCall _recordSettlementCall;
  final IImageService? _imageService;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _firestoreSubs = {};

  /// Whom each event's mirror is limited to, or null for all expenses.
  final Map<String, String?> _mirrorScopes = {};

  CollectionReference<Map<String, dynamic>> _expensesRef(String eventId) =>
      _firestore.collection('events').doc(eventId).collection('expenses');

  /// The expenses a reader may list. A Vendor or Observer must query with
  /// `involvedUids array-contains`, because rules refuse a query that could
  /// return an expense they cannot read (Req 32).
  Query<Map<String, dynamic>> _expensesQuery(
    String eventId,
    String? involving,
  ) => involving == null
      ? _expensesRef(eventId)
      : _expensesRef(eventId).where('involvedUids', arrayContains: involving);

  static bool _involves(ExpenseModel e, String uid) =>
      e.payerId == uid || e.splits.any((s) => s.userId == uid);

  @override
  Stream<List<ExpenseModel>> watchExpensesByEventId(
    String eventId, {
    String? involving,
  }) {
    // Web has no Drift persistence (Wasm is in-memory) and the empty-table
    // watch on Wasm Drift does not reliably emit its first frame. Match
    // `EventRepository.watchEventsForUser`'s web fork: read straight from
    // Firestore. `_fromFirestore` parses the inline splits array, so no
    // subcollection follow-up is needed.
    if (kIsWeb) {
      return _expensesQuery(eventId, involving).snapshots().map(
        (snap) => snap.docs
            .map((doc) => _fromFirestore(doc.id, eventId, doc.data()))
            .toList(),
      );
    }
    _ensureFirestoreMirror(eventId, involving);
    final rows = _expensesDao
        .watchExpensesByEventId(eventId)
        .asyncMap(_hydrateRows);
    if (involving == null) return rows;
    // Rows mirrored before access narrowed stay hidden until the mirror
    // deletes them.
    return rows.map(
      (all) => [
        for (final e in all)
          if (_involves(e, involving)) e,
      ],
    );
  }

  /// Starts the event's mirror, or restarts it when the reader's access
  /// changed. A narrower mirror deletes the rows it no longer returns.
  void _ensureFirestoreMirror(String eventId, String? involving) {
    if (_firestoreSubs.containsKey(eventId) &&
        _mirrorScopes[eventId] == involving) {
      return;
    }
    _firestoreSubs.remove(eventId)?.cancel();
    _mirrorScopes[eventId] = involving;
    var applied = false;
    _firestoreSubs[eventId] = _expensesQuery(eventId, involving)
        .snapshots()
        .listen(
          (snap) {
            final full = !applied;
            applied = true;
            _mirrorSnapshot(eventId, snap, full: full).catchError((
              Object e,
              StackTrace st,
            ) {
              log('Mirror failed', error: e, stackTrace: st, name: 'budget');
            });
          },
          onError: (Object e, StackTrace st) {
            log(
              'Firestore stream error',
              error: e,
              stackTrace: st,
              name: 'budget',
            );
          },
        );
  }

  /// Applies [snap] in one transaction, so the screen updates once (Req
  /// 59). [full] reconciles the whole event, removing rows the query no
  /// longer returns; otherwise only the snapshot's changes are applied.
  Future<void> _mirrorSnapshot(
    String eventId,
    QuerySnapshot<Map<String, dynamic>> snap, {
    required bool full,
  }) => _expensesDao.transaction(() async {
    Future<void> remove(String id) async {
      await _splitsDao.deleteByExpenseId(id);
      await _expensesDao.deleteExpenseById(id);
    }

    if (full) {
      final remoteIds = <String>{};
      for (final doc in snap.docs) {
        remoteIds.add(doc.id);
        await _upsertDrift(_fromFirestore(doc.id, eventId, doc.data()));
      }
      for (final row in await _expensesDao.expensesByEventId(eventId)) {
        if (!remoteIds.contains(row.id)) await remove(row.id);
      }
      return;
    }
    for (final change in snap.docChanges) {
      final doc = change.doc;
      if (change.type == DocumentChangeType.removed) {
        await remove(doc.id);
      } else {
        await _upsertDrift(_fromFirestore(doc.id, eventId, doc.data()!));
      }
    }
  });

  void disposeMirror(String eventId) {
    _firestoreSubs.remove(eventId)?.cancel();
    _mirrorScopes.remove(eventId);
  }

  Future<void> dispose() async {
    for (final sub in _firestoreSubs.values) {
      await sub.cancel();
    }
    _firestoreSubs.clear();
  }

  /// An ID for a new settlement. Keep it across retries, so a payment that
  /// reached the server is not recorded twice.
  String newSettlementId(String eventId) => _expensesRef(eventId).doc().id;

  /// Records a payment from [payerId] to [payeeId] through the
  /// `recordSettlement` callable, as a single `isPayment: true` expense whose
  /// only split is `(payeeId, amount)`, with its chat notice.
  Future<ExpenseSaveResult> recordSettlement({
    required String eventId,
    required String settlementId,
    required String payerId,
    required String payeeId,
    required double amount,
  }) => _callAndMirror(
    () => _recordSettlementCall(
      eventId: eventId,
      settlementId: settlementId,
      payerId: payerId,
      payeeId: payeeId,
      amount: amount,
    ),
    ExpenseModel(
      id: settlementId,
      eventId: eventId,
      payerId: payerId,
      amount: amount,
      isPayment: true,
      splits: [ExpenseSplit(userId: payeeId, amount: amount)],
    ),
  );

  /// Uploads a receipt to Storage at `events/{eid}/receipts/{exid}.jpg`.
  /// Returns the download URL on success, or `null` on failure (caller may
  /// still persist the expense without a receipt and offer a Retry CTA).
  Future<String?> uploadReceipt({
    required String eventId,
    required String expenseId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final svc = _imageService;
    if (svc == null) {
      log(
        'uploadReceipt called without IImageService injected',
        name: 'budget',
      );
      return null;
    }
    try {
      final url = await svc.uploadToStorage(
        bytes: bytes,
        storagePath: 'events/$eventId/receipts/$expenseId.jpg',
        contentType: contentType,
      );
      return url;
    } catch (e, st) {
      log('Receipt upload failed', error: e, stackTrace: st, name: 'budget');
      return null;
    }
  }

  @override
  Future<List<ExpenseModel>> getExpensesByEventId(String eventId) async {
    try {
      final rows = await _expensesDao.expensesByEventId(eventId);
      // `await` is load-bearing: without it the future escapes the try
      // block and a rejection from _hydrateRows would bypass the catch
      // below instead of degrading to an empty list.
      return await _hydrateRows(rows);
    } catch (e, st) {
      log('Failed to get expenses', error: e, stackTrace: st, name: 'budget');
      return [];
    }
  }

  /// Creates or edits an expense through the `saveExpense` callable. It is
  /// safe to retry, because the expense keeps its ID.
  @override
  Future<ExpenseSaveResult> saveExpense(ExpenseModel expense) =>
      _callAndMirror(() => _saveExpenseCall(expense), expense);

  Future<ExpenseSaveResult> _callAndMirror(
    Future<void> Function() call,
    ExpenseModel expense,
  ) async {
    try {
      await call();
    } on FirebaseFunctionsException catch (e, st) {
      log('Failed to save expense', error: e, stackTrace: st, name: 'budget');
      return isConnectionFailure(e)
          ? ExpenseSaveResult.needsConnection
          : ExpenseSaveResult.rejected;
    } catch (e, st) {
      log('Failed to save expense', error: e, stackTrace: st, name: 'budget');
      return ExpenseSaveResult.rejected;
    }
    try {
      await _upsertDrift(expense);
    } catch (e, st) {
      // Already saved on the server, and the mirror will catch up.
      log('Failed to mirror expense', error: e, stackTrace: st, name: 'budget');
    }
    return ExpenseSaveResult.saved;
  }

  @override
  Future<bool> deleteExpense(String id) async {
    try {
      final row = await (_expensesDao.select(
        _expensesDao.expenses,
      )..where((e) => e.id.equals(id))).getSingleOrNull();
      if (row != null) {
        await _expensesRef(row.eventId).doc(id).delete();
      }
      await _splitsDao.deleteByExpenseId(id);
      await _expensesDao.deleteExpenseById(id);
      return true;
    } catch (e, st) {
      log('Failed to delete expense', error: e, stackTrace: st, name: 'budget');
      return false;
    }
  }

  Future<void> _upsertDrift(ExpenseModel expense) async {
    await _expensesDao.insertOrReplace(
      ExpensesCompanion(
        id: Value(expense.id),
        eventId: Value(expense.eventId),
        payerId: Value(expense.payerId),
        amount: Value(expense.amount),
        description: Value(expense.description),
        receiptPath: Value(expense.receiptPath),
        isDonation: Value(expense.isDonation),
        isPayment: Value(expense.isPayment),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _splitsDao.deleteByExpenseId(expense.id);
    for (final split in expense.splits) {
      await _splitsDao.upsert(
        ExpenseSplitsCompanion.insert(
          expenseId: expense.id,
          userId: split.userId,
          amount: split.amount,
        ),
      );
    }
  }

  Future<List<ExpenseModel>> _hydrateRows(List<db.Expense> rows) async {
    final results = <ExpenseModel>[];
    for (final row in rows) {
      final splits = await _splitsDao.byExpenseId(row.id);
      results.add(_toDomain(row, splits));
    }
    return results;
  }

  ExpenseModel _toDomain(db.Expense row, List<db.ExpenseSplit> splits) =>
      ExpenseModel(
        id: row.id,
        eventId: row.eventId,
        payerId: row.payerId,
        amount: row.amount,
        description: row.description,
        receiptPath: row.receiptPath,
        isDonation: row.isDonation,
        isPayment: row.isPayment,
        splits: splits
            .map((s) => ExpenseSplit(userId: s.userId, amount: s.amount))
            .toList(),
        createdAt: row.createdAt,
      );

  ExpenseModel _fromFirestore(
    String id,
    String eventId,
    Map<String, dynamic> data,
  ) {
    final rawSplits = (data['splits'] as List<dynamic>?) ?? const [];
    return ExpenseModel(
      id: id,
      eventId: eventId,
      payerId: (data['payerId'] as String?) ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      description: data['description'] as String?,
      receiptPath: data['receiptPath'] as String?,
      isDonation: (data['isDonation'] as bool?) ?? false,
      isPayment: (data['isPayment'] as bool?) ?? false,
      splits: rawSplits
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => ExpenseSplit(
              userId: (m['userId'] as String?) ?? '',
              amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
            ),
          )
          .toList(),
    );
  }
}
