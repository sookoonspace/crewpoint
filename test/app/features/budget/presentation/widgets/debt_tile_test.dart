import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/debt_tile.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

const _event = EventModel(
  id: 'evt-1',
  title: 'Tahoe Trip',
  creatorId: 'me',
  memberIds: ['me', 'alex'],
  currency: 'USD',
);

const _debt = DebtRow(
  counterpartyUid: 'alex',
  counterpartyName: 'Alex Chen',
  event: _event,
  amount: 45,
  currency: 'USD',
);

void main() {
  testWidgets(
    'renders Settle Up button under the right key; tap fires onSettleUp seam exactly once',
    (tester) async {
      DebtRow? captured;
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebtTile(
              row: _debt,
              onSettleUp: (_, row) {
                captured = row;
                taps++;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final btn = find.byKey(const Key('budget.ledger.settleUp.alex.evt-1'));
      expect(btn, findsOneWidget);
      expect(find.text('Settle Up'), findsOneWidget);

      await tester.tap(btn);
      await tester.pump();
      expect(taps, 1);
      expect(captured?.counterpartyUid, 'alex');
      expect(captured?.event.id, 'evt-1');
    },
  );

  testWidgets('button is disabled when no onSettleUp callback is wired', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DebtTile(row: _debt)),
      ),
    );
    await tester.pump();

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('wraps content in a Card for the elevated-tile look', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DebtTile(row: _debt)),
      ),
    );
    expect(
      find.descendant(of: find.byType(DebtTile), matching: find.byType(Card)),
      findsOneWidget,
    );
  });
}
