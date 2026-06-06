import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/balance_tile.dart';
import 'package:crewpoint_app/app/core/widgets/conversation_tile.dart';
import 'package:crewpoint_app/app/core/widgets/event_tile.dart';
import 'package:crewpoint_app/app/core/widgets/segmented_filter_bar.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/debt_tile.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/recent_expense_tile.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// 320 px overflow audit — the spec calls out the narrowest expected viewport
/// (iPhone SE 1st-gen / pre-zoom Android). The tile widgets named here are
/// the highest-risk overflow sites identified during the audit.
void main() {
  Future<void> pumpAt320(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(child: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'ConversationTile with URGENT + long title at 320 px does not overflow',
    (tester) async {
      await pumpAt320(
        tester,
        const ConversationTile(
          icon: Icons.people_alt_outlined,
          title: 'NYC New Year Eve 2026 — long enough title to push',
          preview: 'Casey: Deposit due Friday at 5pm',
          timestamp: 'Yesterday',
          unreadCount: 99,
          isUrgent: true,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('EventTile with long title at 320 px does not overflow', (
    tester,
  ) async {
    final event = EventModel(
      id: 'evt-a',
      title: 'Tahoe Ski Trip — Long enough title to push the layout',
      creatorId: 'me',
      eventType: EventType.trip,
      memberIds: const ['me', 'bo', 'sk', 'jo'],
      startDate: DateTime(2026, 12, 12),
      endDate: DateTime(2026, 12, 15),
    );
    await pumpAt320(
      tester,
      EventTile(event: event, todo: 4, doing: 3, done: 12),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'DebtTile with large amount + Settle Up button at 320 px does not overflow',
    (tester) async {
      const event = EventModel(
        id: 'evt-1',
        title: 'Tahoe Ski Trip — verbose name',
        creatorId: 'me',
        memberIds: ['me', 'alex'],
        currency: 'USD',
      );
      const debt = DebtRow(
        counterpartyUid: 'alex-with-a-pretty-long-handle',
        counterpartyName: 'Alexandra With A Pretty Long Display Name',
        event: event,
        amount: 1234.56,
        currency: 'USD',
      );
      await pumpAt320(tester, DebtTile(row: debt, onSettleUp: (_, _) {}));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'RecentExpenseTile with long description at 320 px does not overflow',
    (tester) async {
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
        amount: 245.99,
        description:
            'Group dinner with everyone on opening night including ride share',
      );
      await pumpAt320(
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
    },
  );

  testWidgets(
    'SegmentedFilterBar (default scroll) with 4 long labels at 320 px does not crush text',
    (tester) async {
      await pumpAt320(
        tester,
        SegmentedFilterBar<int>(
          selected: 0,
          segments: const [
            SegmentedFilterSegment(value: 0, label: 'All Things'),
            SegmentedFilterSegment(value: 1, label: 'Things To Do'),
            SegmentedFilterSegment(value: 2, label: 'In Progress'),
            SegmentedFilterSegment(value: 3, label: 'Completed'),
          ],
          onChanged: (_) {},
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SegmentedFilterBar(equalWidth: true) with 2 short labels at 320 px fits without overflow',
    (tester) async {
      await pumpAt320(
        tester,
        SegmentedFilterBar<int>(
          selected: 0,
          equalWidth: true,
          segments: const [
            SegmentedFilterSegment(value: 0, label: 'Upcoming'),
            SegmentedFilterSegment(value: 1, label: 'Past'),
          ],
          onChanged: (_) {},
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'BalanceTile renders large youOwe ("\$99,999.99") on a single line at 320 px',
    (tester) async {
      await pumpAt320(
        tester,
        const BalanceTile(owedToYou: 0, youOwe: 99999.99, currencyCode: 'USD'),
      );
      expect(tester.takeException(), isNull);

      final ownedKey = find.byKey(const Key('balance.tile.youOwe'));
      expect(ownedKey, findsOneWidget);
      // MoneyText renders a single inner Text; FittedBox(scaleDown)
      // preserves the full glyph string.
      final innerText = tester.widget<Text>(
        find.descendant(of: ownedKey, matching: find.byType(Text)),
      );
      expect(innerText.data, contains('99,999.99'));

      // Single visual line — height stays close to the font line height.
      // Numbers wrap to a second line in the broken state, doubling the
      // measured height. Pick a generous cap (50 px) — single-line 28pt
      // hero numbers sit at ~33 px on this fixture; two lines push past
      // 60 px.
      final size = tester.getSize(ownedKey);
      expect(
        size.height,
        lessThan(50),
        reason: 'long youOwe must render on one line; measured ${size.height}',
      );
    },
  );
}
