import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';

/// Settle-up tap callback. Production wires this to
/// `SettleUpController.handleSettleUp`; tests inject a recorder.
typedef OnSettleUp = void Function(BuildContext context, DebtRow row);

/// Counterparty avatar + name + event chip + amount + Settle Up button.
class DebtTile extends StatelessWidget {
  const DebtTile({super.key, required this.row, this.onSettleUp});

  final DebtRow row;
  final OnSettleUp? onSettleUp;

  String _firstLetter(String s) =>
      s.isEmpty ? '?' : s.characters.first.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: AppColors.white,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      child: Padding(
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
                  color: Theme.of(context).colorScheme.onSurface,
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
                      color: Theme.of(context).colorScheme.onSurface,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(
                  amount: row.amount,
                  currencyCode: row.currency,
                  sign: MoneySign.youOwe,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  key: Key(
                    'budget.ledger.settleUp.${row.counterpartyUid}.${row.event.id}',
                  ),
                  onPressed: onSettleUp == null
                      ? null
                      : () => onSettleUp!(context, row),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.terracotta,
                    side: const BorderSide(color: AppColors.sage),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                  ),
                  child: Text(context.strings.budget.ledgerSettleUpCta),
                ),
              ],
            ),
          ],
        ),
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
