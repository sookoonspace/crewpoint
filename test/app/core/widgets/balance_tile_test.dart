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

  testWidgets('divider stretches to full content height — fix for 2026-06-11 '
      'iPhone 12 mini Budget tab where the divider stopped above the '
      'amount row', (tester) async {
    await pump(
      tester,
      const BalanceTile(owedToYou: 0, youOwe: 333.33, currencyCode: 'USD'),
    );

    final dividerHeight = tester
        .getSize(find.byKey(const Key('balance.tile.divider')))
        .height;
    // The Row stacks a label (~14 px) + 2-px gap + amount (~36 px display
    // size) > 50 px. The pre-fix divider was hard-coded to 40 px and
    // stopped above the amount. Threshold of 50 px cleanly separates
    // the two states without coupling the assertion to exact text
    // metrics.
    expect(
      dividerHeight,
      greaterThan(50.0),
      reason:
          'Divider height was $dividerHeight px; the fix wraps the inner '
          'Row in IntrinsicHeight so the divider matches column height '
          '(>50 px). Anything <=50 means the fixed 40-px divider '
          'regressed.',
    );
  });
}
