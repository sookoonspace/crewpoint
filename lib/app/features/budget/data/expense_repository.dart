import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crewpoint_app/app/core/database/app_database.dart' as db;
import 'package:crewpoint_app/app/core/database/app_database.dart'
    show ExpensesCompanion, ExpenseSplitsCompanion;
import 'package:crewpoint_app/app/core/database/daos/expense_splits_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expenses_dao.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/repositories/i_expense_repository.dart';

class ExpenseRepository implements IExpenseRepository {
  ExpenseRepository({
    required ExpensesDao expensesDao,
    required ExpenseSplitsDao splitsDao,
    required FirebaseFirestore firestore,
    IImageService? imageService,
  }) : _expensesDao = expensesDao,
       _splitsDao = splitsDao,
       _firestore = firestore,
       _imageService = imageService;

  final ExpensesDao _expensesDao;
  final ExpenseSplitsDao _splitsDao;
  final FirebaseFirestore _firestore;
  final IImageService? _imageService;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _firestoreSubs = {};

  CollectionReference<Map<String, dynamic>> _expensesRef(String eventId) =>
      _firestore.collection('events').doc(eventId).collection('expenses');

  @override
  Stream<List<ExpenseModel>> watchExpensesByEventId(String eventId) {
    // Web has no Drift persistence (Wasm is in-memory) and the empty-table
    // watch on Wasm Drift does not reliably emit its first frame. Match
    // `EventRepository.watchEventsForUser`'s web fork: read straight from
    // Firestore. `_fromFirestore` parses the inline splits array, so no
    // subcollection follow-up is needed.
    if (kIsWeb) {
      return _expensesRef(eventId).snapshots().map(
        (snap) => snap.docs
            .map((doc) => _fromFirestore(doc.id, eventId, doc.data()))
            .toList(),
      );
    }
    _ensureFirestoreMirror(eventId);
    return _expensesDao.watchExpensesByEventId(eventId).asyncMap(_hydrateRows);
  }

  void _ensureFirestoreMirror(String eventId) {
    if (_firestoreSubs.containsKey(eventId)) return;
    _firestoreSubs[eventId] = _expensesRef(eventId).snapshots().listen(
      (snap) {
        _mirrorSnapshot(eventId, snap).catchError((Object e, StackTrace st) {
          log('Mirror failed', error: e, stackTrace: st, name: 'budget');
        });
      },
      onError: (Object e, StackTrace st) {
        log('Firestore stream error', error: e, stackTrace: st, name: 'budget');
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
      final expense = _fromFirestore(doc.id, eventId, doc.data());
      await _upsertDrift(expense);
    }
    final localRows = await _expensesDao.expensesByEventId(eventId);
    for (final row in localRows) {
      if (!remoteIds.contains(row.id)) {
        await _splitsDao.deleteByExpenseId(row.id);
        await _expensesDao.deleteExpenseById(row.id);
      }
    }
  }

  void disposeMirror(String eventId) {
    _firestoreSubs.remove(eventId)?.cancel();
  }

  Future<void> dispose() async {
    for (final sub in _firestoreSubs.values) {
      await sub.cancel();
    }
    _firestoreSubs.clear();
  }

  /// Records a settlement payment from [payerId] to [payeeId] as a single
  /// `isPayment: true` expense whose only split is `(payeeId, -amount)`.
  /// This integrates with the existing [BalanceLedger] payment handling.
  /// Returns the generated expense id (which doubles as the chat-notice id),
  /// or `null` on failure.
  Future<String?> recordSettlement({
    required String eventId,
    required String payerId,
    required String payeeId,
    required double amount,
  }) async {
    final id = _firestore
        .collection('events')
        .doc(eventId)
        .collection('expenses')
        .doc()
        .id;
    final expense = ExpenseModel(
      id: id,
      eventId: eventId,
      payerId: payerId,
      amount: amount,
      isPayment: true,
      splits: [ExpenseSplit(userId: payeeId, amount: -amount)],
    );
    final ok = await createExpense(expense);
    return ok ? id : null;
  }

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

  @override
  Future<bool> createExpense(ExpenseModel expense) async {
    try {
      await _expensesRef(
        expense.eventId,
      ).doc(expense.id).set(_toFirestore(expense));
      await _upsertDrift(expense);
      return true;
    } catch (e, st) {
      log('Failed to create expense', error: e, stackTrace: st, name: 'budget');
      return false;
    }
  }

  /// Updates an existing expense via Firestore `update()`. Locks
  /// `payerId`/`eventId`/`id` field shape per `firestore.rules` (those are
  /// the immutable fields the rules enforce).
  Future<bool> updateExpense(ExpenseModel expense) async {
    try {
      await _expensesRef(
        expense.eventId,
      ).doc(expense.id).update(_toFirestore(expense));
      await _upsertDrift(expense);
      return true;
    } catch (e, st) {
      log('Failed to update expense', error: e, stackTrace: st, name: 'budget');
      return false;
    }
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

  Map<String, dynamic> _toFirestore(ExpenseModel expense) => {
    'eventId': expense.eventId,
    'payerId': expense.payerId,
    'amount': expense.amount,
    'description': expense.description,
    'receiptPath': expense.receiptPath,
    'isDonation': expense.isDonation,
    'isPayment': expense.isPayment,
    'splits': expense.splits
        .map((s) => {'userId': s.userId, 'amount': s.amount})
        .toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

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
