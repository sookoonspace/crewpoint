import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';

/// What the "Your balance" card says (Spec #186): [me]'s net balance, who
/// pays them and whom they pay, largest first. Pure, so it works the same
/// for the server's balance of someone who may not read every expense.
({double net, List<Settlement> owedToMe, List<Settlement> iOwe})
myBalanceSummary(BalanceLedger ledger, String me) {
  int largest(Settlement a, Settlement b) => b.amount.compareTo(a.amount);
  return (
    net: ledger.netBalances[me] ?? 0,
    owedToMe: [
      for (final s in ledger.settlements)
        if (s.toUserId == me) s,
    ]..sort(largest),
    iOwe: [
      for (final s in ledger.settlements)
        if (s.fromUserId == me) s,
    ]..sort(largest),
  );
}

/// The symbol shown before amounts in the event's currency. Unknown codes
/// fall back to `$`.
String currencySymbolFor(String code) => switch (code) {
  'USD' || 'CAD' || 'AUD' => r'$',
  'EUR' => '€',
  'GBP' => '£',
  'JPY' => '¥',
  'INR' => '₹',
  _ => r'$',
};
