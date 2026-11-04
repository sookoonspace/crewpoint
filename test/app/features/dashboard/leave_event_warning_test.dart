import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/event_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _event = EventModel(
  id: 'evt',
  title: 'Trip',
  creatorId: 'owner',
  memberIds: ['owner', 'me'],
  currency: 'USD',
);

ExpenseModel _expense(String payer, String owing) => ExpenseModel(
  id: 'e',
  eventId: 'evt',
  payerId: payer,
  amount: 40,
  splits: [
    ExpenseSplit(userId: payer, amount: 20),
    ExpenseSplit(userId: owing, amount: 20),
  ],
);

Future<void> _openLeave(
  WidgetTester tester,
  Stream<List<ExpenseModel>> expenses,
) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('me'),
        expenseListProvider.overrideWith((ref, _) => expenses),
      ],
      child: const MaterialApp(home: EventDashboardScreen(event: _event)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byKey(const Key('event.action.leave')));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

const _warning = Key('event.leave.balanceWarning');
const _leave = Key('event.leave.confirm');

void main() {
  testWidgets('warns someone who owes money, and does not block them', (
    tester,
  ) async {
    await _openLeave(tester, Stream.value([_expense('owner', 'me')]));
    expect(find.byKey(_warning), findsOneWidget);
    expect(find.byKey(_leave), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(_leave)).onPressed, isNotNull);
  });

  testWidgets('warns someone who is owed money', (tester) async {
    await _openLeave(tester, Stream.value([_expense('me', 'owner')]));
    expect(find.byKey(_warning), findsOneWidget);
  });

  testWidgets('no warning with a settled balance', (tester) async {
    await _openLeave(tester, Stream.value(const []));
    expect(find.byKey(_warning), findsNothing);
    expect(find.byKey(_leave), findsOneWidget);
  });

  testWidgets('if expenses cannot load, leaving still works', (tester) async {
    await _openLeave(tester, Stream.error(StateError('offline')));
    expect(find.byKey(_warning), findsNothing);
    expect(find.byKey(_leave), findsOneWidget);
  });
}
