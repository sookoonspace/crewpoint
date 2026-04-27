import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/settle_sheet.dart';

void main() {
  const settlement = Settlement(fromUserId: 'me', toUserId: 'them', amount: 25);

  testWidgets('Venmo button enabled with handle, CashApp disabled without', (
    tester,
  ) async {
    var venmoTaps = 0;
    var cashTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettleSheet(
            settlement: settlement,
            currencySymbol: '\$',
            venmoHandle: 'alex',
            cashappHandle: null,
            onPayVenmo: () => venmoTaps++,
            onPayCashApp: () => cashTaps++,
          ),
        ),
      ),
    );

    final venmo = tester.widget<ElevatedButton>(
      find.byKey(const Key('budget.settle.venmo')),
    );
    expect(venmo.onPressed, isNotNull);

    final cash = tester.widget<OutlinedButton>(
      find.byKey(const Key('budget.settle.cashapp')),
    );
    expect(cash.onPressed, isNull);

    await tester.tap(find.byKey(const Key('budget.settle.venmo')));
    expect(venmoTaps, 1);
    expect(cashTaps, 0);
  });

  testWidgets('Both pay buttons disabled when no handles, copy stays enabled', (
    tester,
  ) async {
    var copyTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettleSheet(
            settlement: settlement,
            currencySymbol: '\$',
            onPayVenmo: () {},
            onPayCashApp: () {},
            onCopyDetails: () => copyTaps++,
          ),
        ),
      ),
    );

    final venmo = tester.widget<ElevatedButton>(
      find.byKey(const Key('budget.settle.venmo')),
    );
    expect(venmo.onPressed, isNull);

    final cash = tester.widget<OutlinedButton>(
      find.byKey(const Key('budget.settle.cashapp')),
    );
    expect(cash.onPressed, isNull);

    await tester.tap(find.byKey(const Key('budget.settle.copy')));
    expect(copyTaps, 1);
  });

  testWidgets('amount renders with the supplied currency symbol', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettleSheet(settlement: settlement, currencySymbol: '€'),
        ),
      ),
    );

    expect(find.text('€25.00'), findsOneWidget);
  });
}
