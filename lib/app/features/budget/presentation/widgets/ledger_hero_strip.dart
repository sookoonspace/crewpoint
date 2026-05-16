import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// Hero strip at the top of the Budget Ledger: two big-typography
/// amounts. Sage for owed-to-you; terracotta for you-owe. Optional
/// multi-currency disclaimer renders when events use different
/// currencies (V1 displays totals without conversion).
class LedgerHeroStrip extends StatelessWidget {
  const LedgerHeroStrip({
    super.key,
    required this.owedToYou,
    required this.youOwe,
    this.showMultiCurrencyDisclaimer = false,
  });

  final double owedToYou;
  final double youOwe;
  final bool showMultiCurrencyDisclaimer;

  String _format(double amount) =>
      NumberFormat.simpleCurrency(name: 'USD').format(amount);

  @override
  Widget build(BuildContext context) {
    final s = context.strings.budget;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Owed to you (sage).
          Text(
            s.ledgerHeroOwedToYouLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.charcoal,
            ),
          ),
          Text(
            _format(owedToYou),
            key: const Key('budget.ledger.hero.owedToYou'),
            style: theme.textTheme.headlineLarge?.copyWith(
              color: AppColors.sage,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // You owe (terracotta).
          Text(
            s.ledgerHeroYouOweLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.charcoal,
            ),
          ),
          Text(
            _format(youOwe),
            key: const Key('budget.ledger.hero.youOwe'),
            style: theme.textTheme.headlineLarge?.copyWith(
              color: AppColors.terracotta,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (showMultiCurrencyDisclaimer) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              s.multiCurrencyDisclaimer,
              key: const Key('budget.ledger.hero.multiCurrency'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.mediumGrey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
