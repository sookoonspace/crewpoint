import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Intent-centric helpers for the cross-event Budget Ledger.
///
/// Selectors must match the widgets under test:
/// - `Key('budget.ledger.hero.{owedToYou,youOwe,multiCurrency}')`
/// - `Key('budget.ledger.debt.{counterpartyUid}.{eventId}')`
/// - `Key('budget.ledger.settleUp.{counterpartyUid}.{eventId}')`
/// - `Key('budget.ledger.allSettled')`
/// - `Key('budget.ledger.recentExpense.{expenseId}')`
/// - `Key('budget.settleUp.fallback.sheet')` + copyAmount / copyHandle / markPaid
class BudgetLedgerRobot {
  BudgetLedgerRobot(this.tester);

  final WidgetTester tester;

  /// Lottie loops forever — bounded pumps, not pumpAndSettle.
  Future<void> pumpFrames({int frames = 3}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  void expectDebtRow(String counterpartyUid, String eventId) {
    expect(
      find.byKey(Key('budget.ledger.debt.$counterpartyUid.$eventId')),
      findsOneWidget,
    );
  }

  Future<void> tapSettleUp(String counterpartyUid, String eventId) async {
    await tester.tap(
      find.byKey(Key('budget.ledger.settleUp.$counterpartyUid.$eventId')),
    );
    await pumpFrames();
  }

  void expectFallbackSheetVisible() {
    expect(
      find.byKey(const Key('budget.settleUp.fallback.sheet')),
      findsOneWidget,
    );
  }

  void expectFallbackSheetGone() {
    expect(
      find.byKey(const Key('budget.settleUp.fallback.sheet')),
      findsNothing,
    );
  }

  Future<void> tapFallbackCopyAmount() async {
    await tester.tap(
      find.byKey(const Key('budget.settleUp.fallback.copyAmount')),
    );
    await pumpFrames();
  }

  Future<void> tapFallbackMarkPaid() async {
    await tester.tap(
      find.byKey(const Key('budget.settleUp.fallback.markPaid')),
    );
    await pumpFrames();
  }
}
