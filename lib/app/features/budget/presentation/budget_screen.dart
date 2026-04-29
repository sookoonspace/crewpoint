import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_tile.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/settle_sheet.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({
    super.key,
    required this.expenses,
    required this.memberIds,
    this.currency = 'USD',
    this.memberNames = const {},
    this.onAddExpense,
    this.onRecordPayment,
    this.onExportPdf,
    this.onExportCsv,
  });

  final List<ExpenseModel> expenses;
  final List<String> memberIds;
  final String currency;
  final Map<String, String> memberNames;
  final VoidCallback? onAddExpense;
  final void Function(Settlement settlement)? onRecordPayment;
  final VoidCallback? onExportPdf;
  final VoidCallback? onExportCsv;

  String _currencySymbol(String code) => switch (code) {
    'USD' || 'CAD' || 'AUD' => '\$',
    'EUR' => '€',
    'GBP' => '£',
    'JPY' => '¥',
    'INR' => '₹',
    _ => '\$',
  };

  @override
  Widget build(BuildContext context) {
    final ledger = BalanceLedger.calculate(
      expenses: expenses,
      memberIds: memberIds,
    );
    final regularExpenses = expenses.where((e) => !e.isPayment).toList();
    final symbol = _currencySymbol(currency);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Budget'),
        backgroundColor: AppColors.cream,
        elevation: 0,
        actions: [
          if (onExportPdf != null || onExportCsv != null)
            PopupMenuButton<String>(
              key: const Key('budget.export.menu'),
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export',
              onSelected: (value) {
                switch (value) {
                  case 'pdf':
                    onExportPdf?.call();
                  case 'csv':
                    onExportCsv?.call();
                }
              },
              itemBuilder: (_) => [
                if (onExportPdf != null)
                  const PopupMenuItem(
                    key: Key('budget.export.pdf'),
                    value: 'pdf',
                    child: Text('Export PDF'),
                  ),
                if (onExportCsv != null)
                  const PopupMenuItem(
                    key: Key('budget.export.csv'),
                    value: 'csv',
                    child: Text('Export CSV'),
                  ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Total summary
          _TotalCard(total: ledger.totalExpenses, symbol: symbol),
          const SizedBox(height: AppSpacing.xl),

          // Balances
          if (memberIds.length > 1) ...[
            const _SectionLabel(label: 'BALANCES'),
            const SizedBox(height: AppSpacing.sm),
            _BalancesCard(
              balances: ledger.netBalances,
              memberNames: memberNames,
              symbol: symbol,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // Settle Up
          if (ledger.settlements.isNotEmpty) ...[
            const _SectionLabel(label: 'SETTLE UP'),
            const SizedBox(height: AppSpacing.sm),
            _SettleUpCard(
              settlements: ledger.settlements,
              memberNames: memberNames,
              symbol: symbol,
              onSettle: (settlement) {
                if (onRecordPayment != null) {
                  onRecordPayment!(settlement);
                } else {
                  // Fallback for screens that don't wire onRecordPayment.
                  // EventBudgetPage supplies it with the full pay flow.
                  SettleSheet.show(
                    context: context,
                    settlement: settlement,
                    currencySymbol: symbol,
                    fromName: memberNames[settlement.fromUserId],
                    toName: memberNames[settlement.toUserId],
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // Expenses list
          const _SectionLabel(label: 'EXPENSES'),
          const SizedBox(height: AppSpacing.sm),
          if (regularExpenses.isEmpty)
            const _EmptyExpenses()
          else
            ...regularExpenses.map(
              (e) => ExpenseTile(expense: e, currencySymbol: symbol),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('budget.expense.create'),
        onPressed: onAddExpense,
        backgroundColor: AppColors.sage,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.symbol});

  final double total;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderLg,
        side: BorderSide(
          color: AppColors.lightGrey.withValues(alpha: 0.7),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Text(
              'Total Expenses',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.darkGrey),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$symbol${total.toStringAsFixed(2)}',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.darkGrey,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BalancesCard extends StatelessWidget {
  const _BalancesCard({
    required this.balances,
    required this.memberNames,
    required this.symbol,
  });

  final Map<String, double> balances;
  final Map<String, String> memberNames;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final entries = balances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderLg,
        side: BorderSide(
          color: AppColors.lightGrey.withValues(alpha: 0.7),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _BalanceRow(
              name: memberNames[entries[i].key] ?? entries[i].key,
              balance: entries[i].value,
              symbol: symbol,
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.name,
    required this.balance,
    required this.symbol,
  });

  final String name;
  final double balance;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final isPositive = balance > 0.01;
    final isNegative = balance < -0.01;
    final color = isPositive
        ? AppColors.sage
        : isNegative
        ? AppColors.terracotta
        : AppColors.darkGrey;
    final prefix = isPositive ? '+' : '';
    final label = isPositive
        ? 'is owed'
        : isNegative
        ? 'owes'
        : 'settled';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(name, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGrey),
                ),
              ],
            ),
          ),
          Text(
            '$prefix$symbol${balance.abs().toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettleUpCard extends StatelessWidget {
  const _SettleUpCard({
    required this.settlements,
    required this.memberNames,
    required this.symbol,
    required this.onSettle,
  });

  final List<Settlement> settlements;
  final Map<String, String> memberNames;
  final String symbol;
  final ValueChanged<Settlement> onSettle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderLg,
        side: BorderSide(
          color: AppColors.lightGrey.withValues(alpha: 0.7),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          for (var i = 0; i < settlements.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _SettlementRow(
              settlement: settlements[i],
              fromName:
                  memberNames[settlements[i].fromUserId] ??
                  settlements[i].fromUserId,
              toName:
                  memberNames[settlements[i].toUserId] ??
                  settlements[i].toUserId,
              symbol: symbol,
              onSettle: () => onSettle(settlements[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({
    required this.settlement,
    required this.fromName,
    required this.toName,
    required this.symbol,
    required this.onSettle,
  });

  final Settlement settlement;
  final String fromName;
  final String toName;
  final String symbol;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  '$fromName pays $toName',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '$symbol${settlement.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.terracotta,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: Key('budget.settle.${settlement.toUserId}'),
            onPressed: onSettle,
            style: TextButton.styleFrom(foregroundColor: AppColors.sage),
            child: const Text('Settle'),
          ),
        ],
      ),
    );
  }
}

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Text(
          'No expenses yet',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGrey),
        ),
      ),
    );
  }
}
