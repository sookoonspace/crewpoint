import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense});

  final ExpenseModel expense;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: expense.isDonation
                    ? AppColors.sageLight.withValues(alpha: 0.3)
                    : AppColors.lightGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                expense.isDonation ? Icons.volunteer_activism : Icons.receipt,
                color: expense.isDonation ? AppColors.sage : AppColors.charcoal,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    expense.description ?? 'Expense',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (expense.isDonation)
                    Text(
                      'Donated',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: AppColors.sage),
                    ),
                ],
              ),
            ),
            Text(
              '\$${expense.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
