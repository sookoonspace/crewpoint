import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/repositories/i_expense_repository.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_modal.dart';
import 'package:crewpoint_app/app/features/profile/data/firestore_user_repository.dart';

/// Req 43a: an equal split includes everyone up to 50 members. Past that,
/// the person adding it chooses who shares it, through the paged picker.
void main() {
  late FakeFirebaseFirestore firestore;
  late List<ExpenseModel> saved;

  List<String> members(int n) => [for (var i = 0; i < n; i++) 'u$i'];

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    saved = [];
    final profiles = firestore
        .collection('events')
        .doc('e1')
        .collection('profiles');
    for (var i = 0; i < 5; i++) {
      await profiles.doc('u$i').set({
        'uid': 'u$i',
        'displayName': 'Person $i',
        'sortName': 'person $i',
        'inEvent': true,
      });
    }
  });

  Future<void> pump(
    WidgetTester tester, {
    required List<String> memberIds,
    ExpenseModel? initial,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FirestoreUserRepository(firestore: firestore),
          ),
          currentUserIdProvider.overrideWithValue('u0'),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const Key('open'),
                onPressed: () => ExpenseModal.show(
                  context: context,
                  eventId: 'e1',
                  payerId: 'u0',
                  memberIds: memberIds,
                  initial: initial,
                  onSubmit: (expense, _) async {
                    saved.add(expense);
                    return ExpenseSaveResult.saved;
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  Future<void> enterAmount(WidgetTester tester, String amount) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('budget.expense.amount')),
        matching: find.byType(TextField),
      ),
      amount,
    );
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('budget.expense.save')));
    await tester.pumpAndSettle();
  }

  testWidgets('up to 50 members, everyone shares by default', (tester) async {
    await pump(tester, memberIds: members(3));
    expect(find.text('Everyone (3)'), findsOneWidget);
    await enterAmount(tester, '30');
    await save(tester);
    expect(saved.single.splits.map((s) => s.userId), ['u0', 'u1', 'u2']);
    expect(saved.single.splits.first.amount, 10);
  });

  testWidgets('past 50 members, saving needs choosing who shares it', (
    tester,
  ) async {
    await pump(tester, memberIds: members(51));
    expect(find.byKey(const Key('budget.expense.split.mustChoose')), findsOne);
    await enterAmount(tester, '30');
    await save(tester);
    expect(saved, isEmpty);
    expect(find.byKey(const Key('budget.expense.split.error')), findsOne);

    // Splitting with everyone is still there, but has to be asked for.
    await tester.tap(find.byKey(const Key('budget.expense.split.everyone')));
    await tester.pump();
    expect(find.text('Everyone (51)'), findsOneWidget);
    await save(tester);
    expect(saved.single.splits, hasLength(51));
  });

  testWidgets('people chosen in the picker share it', (tester) async {
    await pump(tester, memberIds: members(60));
    await enterAmount(tester, '30');
    await tester.tap(find.byKey(const Key('budget.expense.split.choose')));
    await tester.pumpAndSettle();
    for (final uid in ['u0', 'u2', 'u4']) {
      await tester.tap(find.byKey(Key('members.picker.row.$uid')));
    }
    await tester.tap(find.byKey(const Key('members.picker.done')));
    await tester.pumpAndSettle();
    expect(find.text('3 people chosen'), findsOneWidget);
    expect(find.textContaining('\$10.00 per person (3 people)'), findsOne);

    await save(tester);
    expect(
      saved.single.splits.map((s) => s.userId),
      unorderedEquals(['u0', 'u2', 'u4']),
    );
  });

  testWidgets('editing starts from who shared it before', (tester) async {
    await pump(
      tester,
      memberIds: members(5),
      initial: const ExpenseModel(
        id: 'x',
        eventId: 'e1',
        payerId: 'u0',
        amount: 20,
        splits: [
          ExpenseSplit(userId: 'u0', amount: 10),
          ExpenseSplit(userId: 'u3', amount: 10),
        ],
      ),
    );
    expect(find.text('2 people chosen'), findsOneWidget);
    await enterAmount(tester, '40');
    await save(tester);
    expect(saved.single.splits.map((s) => s.userId), ['u0', 'u3']);
    expect(saved.single.splits.first.amount, 20);
  });

  testWidgets('leaving with unsaved changes asks first', (tester) async {
    await pump(tester, memberIds: members(3));
    await enterAmount(tester, '12');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('roles.discard.keep')), findsOneWidget);

    await tester.tap(find.byKey(const Key('roles.discard.keep')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('budget.expense.amount')), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('roles.discard.confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('budget.expense.amount')), findsNothing);
    expect(saved, isEmpty);
  });

  testWidgets('the split fits a 375 px phone at 200% text', (tester) async {
    await pump(tester, memberIds: members(60));
    tester.view.physicalSize = const Size(375, 1600);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSize(find.byKey(const Key('budget.expense.split.choose')))
          .height,
      greaterThan(47),
    );
  });
}
