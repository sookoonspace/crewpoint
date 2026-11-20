import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/conversation_tile.dart';
import 'package:crewpoint_app/app/core/widgets/event_tile.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/debt_tile.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/recent_expense_tile.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Sanity check: new design-system widgets remain usable when the OS
/// text scaler is cranked to 200% (the "any age" floor in the spec).
/// We assert no overflow exceptions thrown during layout, which is the
/// hardest failure mode to discover later.
void main() {
  Future<void> pumpScaled(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SafeArea(child: SingleChildScrollView(child: child)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('EventTile survives TextScaler 2.0', (tester) async {
    final event = EventModel(
      id: 'evt-a',
      title: 'Tahoe Ski Trip — Long enough title to push the layout',
      creatorId: 'me',
      displayType: 'trip',
      memberIds: const ['me', 'bo', 'sk'],
      startDate: DateTime(2026, 12, 12),
      endDate: DateTime(2026, 12, 15),
    );
    await pumpScaled(
      tester,
      EventTile(event: event, todo: 2, doing: 1, done: 3),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('MoneyText survives TextScaler 2.0', (tester) async {
    await pumpScaled(
      tester,
      const MoneyText(amount: 1234.56, currencyCode: 'USD'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ConversationTile survives TextScaler 2.0', (tester) async {
    await pumpScaled(
      tester,
      const ConversationTile(
        icon: Icons.people_alt_outlined,
        title: 'NYC New Year — long enough to push the layout',
        preview: 'URGENT: Venue deposit due next Friday by 5pm',
        timestamp: '18m',
        unreadCount: 12,
        isUrgent: true,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('DebtTile survives TextScaler 2.0', (tester) async {
    const event = EventModel(
      id: 'evt-1',
      title: 'Tahoe Trip — long enough title to push the layout',
      creatorId: 'me',
      memberIds: ['me', 'alex'],
      currency: 'USD',
    );
    const debt = DebtRow(
      counterpartyUid: 'alex',
      counterpartyName: 'Alex Chen',
      event: event,
      amount: 123.45,
      currency: 'USD',
    );
    await pumpScaled(tester, const DebtTile(row: debt));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RecentExpenseTile survives TextScaler 2.0', (tester) async {
    const event = EventModel(
      id: 'evt-1',
      title: 'Tahoe Trip',
      creatorId: 'me',
      memberIds: ['me', 'alex'],
      currency: 'USD',
    );
    const expense = ExpenseModel(
      id: 'exp-1',
      eventId: 'evt-1',
      payerId: 'me',
      amount: 45,
      description: 'Pizza delivery for the entire crew on opening night',
    );
    await pumpScaled(
      tester,
      RecentExpenseTile(
        row: const RecentExpenseRow(
          expense: expense,
          event: event,
          payerName: 'You',
        ),
        currentUserId: 'me',
        onTap: () {},
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
