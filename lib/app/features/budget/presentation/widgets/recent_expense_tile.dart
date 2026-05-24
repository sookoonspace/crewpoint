import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';

/// Chronological row in the cross-event "Recent expenses" feed.
class RecentExpenseTile extends StatelessWidget {
  const RecentExpenseTile({
    super.key,
    required this.row,
    required this.currentUserId,
    required this.onTap,
  });

  final RecentExpenseRow row;
  final String currentUserId;
  final VoidCallback onTap;

  String _firstLetter(String s) =>
      s.isEmpty ? '?' : s.characters.first.toUpperCase();

  /// Relative timestamp ("2h" / "yesterday" / "Mar 4"). Older than 30
  /// days uses absolute (spec req 37).
  String _formatTimestamp(DateTime? when) {
    if (when == null) return '';
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return DateFormat.MMMd().format(when);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exp = row.expense;
    final payerLabel = exp.payerId == currentUserId ? 'You' : exp.payerId;
    return Card(
      elevation: 0,
      color: AppColors.white,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('budget.ledger.recentExpense.${exp.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.sageLight,
                child: Text(
                  _firstLetter(payerLabel),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exp.description ?? '$payerLabel paid',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.event.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(
                    amount: exp.amount,
                    currencyCode: row.event.currency,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(exp.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
