import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/balance_tile.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('renders both balances side-by-side', (tester) async {
    await pump(
      tester,
      const BalanceTile(owedToYou: 150.0, youOwe: 45.0, currencyCode: 'USD'),
    );
    expect(find.text(r'$150.00'), findsOneWidget);
    expect(find.text(r'$45.00'), findsOneWidget);
  });

  testWidgets('collapses to "all settled" message when both are zero', (
    tester,
  ) async {
    await pump(
      tester,
      const BalanceTile(owedToYou: 0.0, youOwe: 0.0, currencyCode: 'USD'),
    );
    expect(find.text(r'$0.00 — all settled'), findsOneWidget);
    expect(
      find.byKey(const Key('balance.tile.ratioBar')),
      findsNothing,
      reason: 'ratio bar should not render when both balances are zero',
    );
  });

  testWidgets(
    'renders multi-currency disclaimer when showMultiCurrencyDisclaimer = true',
    (tester) async {
      await pump(
        tester,
        const BalanceTile(
          owedToYou: 10,
          youOwe: 5,
          currencyCode: 'USD',
          multiCurrencyDisclaimer: 'Mixed currencies — totals shown in USD.',
        ),
      );
      expect(
        find.text('Mixed currencies — totals shown in USD.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('omits disclaimer when not provided', (tester) async {
    await pump(
      tester,
      const BalanceTile(owedToYou: 10, youOwe: 5, currencyCode: 'USD'),
    );
    expect(find.byKey(const Key('balance.tile.disclaimer')), findsNothing);
  });
}
