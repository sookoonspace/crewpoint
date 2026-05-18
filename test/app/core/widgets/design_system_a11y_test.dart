import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/balance_tile.dart';
import 'package:crewpoint_app/app/core/widgets/conversation_tile.dart';
import 'package:crewpoint_app/app/core/widgets/event_tile.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';
import 'package:crewpoint_app/app/core/widgets/progress_ring.dart';
import 'package:crewpoint_app/app/core/widgets/screen_header.dart';
import 'package:crewpoint_app/app/core/widgets/segmented_filter_bar.dart';
import 'package:crewpoint_app/app/core/widgets/settings_row.dart';
import 'package:crewpoint_app/app/core/widgets/stat_triplet.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/debt_tile.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/recent_expense_tile.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

enum _Pill { all, todo, doing, done }

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

  testWidgets('ProgressRing survives TextScaler 2.0', (tester) async {
    await pumpScaled(tester, const ProgressRing(todo: 5, doing: 2, done: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ScreenHeader survives TextScaler 2.0', (tester) async {
    await pumpScaled(
      tester,
      const ScreenHeader(
        title: 'Good morning, Alex 👋',
        subtitle: 'Wednesday, December 11',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('EventTile survives TextScaler 2.0', (tester) async {
    final event = EventModel(
      id: 'evt-a',
      title: 'Tahoe Ski Trip — Long enough title to push the layout',
      creatorId: 'me',
      eventType: EventType.trip,
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
      const MoneyText(
        amount: 1234.56,
        currencyCode: 'USD',
        sign: MoneySign.owedToYou,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('SegmentedFilterBar survives TextScaler 2.0', (tester) async {
    await pumpScaled(
      tester,
      SegmentedFilterBar<_Pill>(
        selected: _Pill.all,
        segments: const [
          SegmentedFilterSegment(value: _Pill.all, label: 'All'),
          SegmentedFilterSegment(value: _Pill.todo, label: 'To Do'),
          SegmentedFilterSegment(value: _Pill.doing, label: 'Doing'),
          SegmentedFilterSegment(value: _Pill.done, label: 'Done'),
        ],
        onChanged: (_) {},
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ConversationTile survives TextScaler 2.0', (tester) async {
    await pumpScaled(
      tester,
      const ConversationTile(
        emoji: '🎉',
        title: 'NYC New Year — long enough to push the layout',
        preview: 'URGENT: Venue deposit due next Friday by 5pm',
        timestamp: '18m',
        unreadCount: 12,
        isUrgent: true,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('BalanceTile survives TextScaler 2.0', (tester) async {
    await pumpScaled(
      tester,
      const BalanceTile(
        owedToYou: 150.0,
        youOwe: 45.0,
        currencyCode: 'USD',
        multiCurrencyDisclaimer:
            'Mixed currencies — totals shown in USD without conversion.',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatTriplet survives TextScaler 2.0', (tester) async {
    await pumpScaled(
      tester,
      const StatTriplet(
        cells: [
          StatCell(value: '4', label: 'Events'),
          StatCell(value: '12', label: 'Tasks'),
          StatCell(value: r'$150', label: 'Owed'),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsRow survives TextScaler 2.0', (tester) async {
    await pumpScaled(
      tester,
      const SettingsRow(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications',
        subtitle: 'All alerts on — tap to configure',
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
        row: const RecentExpenseRow(expense: expense, event: event),
        currentUserId: 'me',
        onTap: () {},
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
