import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

/// Someone's own balance in an event and the transfers that settle it,
/// worked out by `getMyBalance` from every expense (Req 38c). For people who
/// may not read every expense, so they still see what they owe and who to
/// pay.
class MyBalance {
  const MyBalance({
    required this.net,
    required this.currency,
    this.transfers = const [],
  });

  factory MyBalance.fromMap(Map<String, dynamic> data) => MyBalance(
    net: (data['net'] as num?)?.toDouble() ?? 0,
    currency: data['currency'] as String? ?? 'USD',
    transfers: [
      for (final t in (data['transfers'] as List?) ?? const [])
        if (t is Map)
          Settlement(
            fromUserId: t['fromUserId'] as String,
            toUserId: t['toUserId'] as String,
            amount: (t['amount'] as num).toDouble(),
          ),
    ],
  );

  /// Positive is owed money, negative owes money.
  final double net;
  final String currency;
  final List<Settlement> transfers;

  /// A ledger showing only [uid]'s balance and transfers, with the total of
  /// the expenses they can read (Req 38c: totals show only what they may
  /// read).
  BalanceLedger toLedger(String uid, List<ExpenseModel> visible) =>
      BalanceLedger(
        netBalances: {uid: net},
        settlements: transfers,
        totalExpenses: visible
            .where((e) => !e.isPayment)
            .fold(0, (total, e) => total + e.amount),
      );
}
