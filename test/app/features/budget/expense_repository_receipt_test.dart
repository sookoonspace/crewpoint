import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart'
    show AppDatabase, EventsCompanion, UsersCompanion;
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expense_splits_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expenses_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/users_dao.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_repository.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

class _FakeImageService implements IImageService {
  bool shouldThrow = false;
  String? lastPath;

  @override
  Future<File?> pickFromGallery({
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 85,
  }) async => null;

  @override
  Future<File?> takePhoto({
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 85,
  }) async => null;

  @override
  Future<String> uploadToStorage({
    required File file,
    required String storagePath,
  }) async {
    lastPath = storagePath;
    if (shouldThrow) {
      throw StateError('upload failed');
    }
    return 'https://cdn.example/$storagePath';
  }
}

void main() {
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  late _FakeImageService imageService;
  late ExpenseRepository repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    imageService = _FakeImageService();
    await UsersDao(
      db,
    ).insertUser(UsersCompanion.insert(id: 'user-1', email: 'a@example.com'));
    await EventsDao(db).insertEvent(
      EventsCompanion.insert(
        id: 'event-1',
        title: 'Trip',
        creatorId: 'user-1',
        startDate: Value(DateTime(2026, 6, 1)),
      ),
    );
    repository = ExpenseRepository(
      expensesDao: ExpensesDao(db),
      splitsDao: ExpenseSplitsDao(db),
      firestore: firestore,
      imageService: imageService,
    );
  });

  tearDown(() => db.close());

  test(
    'uploadReceipt returns the URL on success and uploads to expected path',
    () async {
      final url = await repository.uploadReceipt(
        eventId: 'event-1',
        expenseId: 'exp-1',
        file: File('/tmp/dummy.jpg'),
      );

      expect(
        url,
        equals('https://cdn.example/events/event-1/receipts/exp-1.jpg'),
      );
      expect(
        imageService.lastPath,
        equals('events/event-1/receipts/exp-1.jpg'),
      );
    },
  );

  test('uploadReceipt returns null on failure (caller may still persist '
      'expense without a receipt)', () async {
    imageService.shouldThrow = true;

    final url = await repository.uploadReceipt(
      eventId: 'event-1',
      expenseId: 'exp-1',
      file: File('/tmp/dummy.jpg'),
    );
    expect(url, isNull);

    // Caller can proceed to save the expense without a receipt path.
    const expense = ExpenseModel(
      id: 'exp-1',
      eventId: 'event-1',
      payerId: 'user-1',
      amount: 12.5,
    );
    final saved = await repository.createExpense(expense);
    expect(saved, isTrue);

    final saved2 = await repository.getExpensesByEventId('event-1');
    expect(saved2.first.receiptPath, isNull);
  });
}
