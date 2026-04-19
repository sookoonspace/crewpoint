import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_tile.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key, required this.expenses, this.onAddExpense});

  final List<ExpenseModel> expenses;
  final VoidCallback? onAddExpense;

  double get _total => expenses.fold(0.0, (sum, e) => sum + e.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: Column(
        children: [
          _TotalSummary(total: _total),
          Expanded(
            child: expenses.isEmpty
                ? const Center(
                    child: Text(
                      'No expenses yet',
                      style: TextStyle(color: AppColors.mediumGrey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: expenses.length,
                    itemBuilder: (_, index) =>
                        ExpenseTile(expense: expenses[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onAddExpense,
        backgroundColor: AppColors.sage,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TotalSummary extends StatelessWidget {
  const _TotalSummary({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Text(
            'Total Expenses',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}
