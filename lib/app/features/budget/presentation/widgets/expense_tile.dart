import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/receipt_viewer.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    this.currencySymbol = '\$',
  });

  final ExpenseModel expense;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final hasReceipt =
        expense.receiptPath != null && expense.receiptPath!.isNotEmpty;

    return Card(
      key: Key('budget.expense.tile.${expense.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (hasReceipt)
              GestureDetector(
                key: Key('budget.expense.tile.${expense.id}.thumbnail'),
                onTap: () => ReceiptViewer.show(
                  context: context,
                  imageUrl: expense.receiptPath!,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    expense.receiptPath!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 40,
                      height: 40,
                      color: AppColors.lightGrey,
                      child: const Icon(
                        Icons.broken_image,
                        color: AppColors.mediumGrey,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              )
            else
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
                  color: expense.isDonation
                      ? AppColors.sage
                      : AppColors.charcoal,
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
              '$currencySymbol${expense.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
