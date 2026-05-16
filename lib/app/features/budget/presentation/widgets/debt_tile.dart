import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';

/// Phase 3 shape: counterparty avatar + name + event chip + amount in
/// event currency. Settle Up button lands in Phase 4.
class DebtTile extends StatelessWidget {
  const DebtTile({super.key, required this.row});

  final DebtRow row;

  String _firstLetter(String s) =>
      s.isEmpty ? '?' : s.characters.first.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountText = NumberFormat.simpleCurrency(
      name: row.currency,
    ).format(row.amount);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.sage,
            child: Text(
              _firstLetter(row.counterpartyUid),
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.counterpartyUid,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _EventChip(label: row.event.title),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            amountText,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.terracotta,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.charcoal),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
