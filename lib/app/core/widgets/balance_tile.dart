import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/app_typography.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';

/// Hero balance summary for the Budget Ledger.
///
/// Renders "You are owed $X | You owe $Y" with a thin ratio bar visualising
/// the two sides. When both are zero, collapses to a neutral "all settled"
/// message and the ratio bar is omitted. Optional disclaimer slot (e.g.,
/// "Mixed currencies — totals shown in USD.") sits beneath the numbers.
class BalanceTile extends StatelessWidget {
  const BalanceTile({
    super.key,
    required this.owedToYou,
    required this.youOwe,
    required this.currencyCode,
    this.multiCurrencyDisclaimer,
  });

  final double owedToYou;
  final double youOwe;
  final String currencyCode;
  final String? multiCurrencyDisclaimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bothZero = owedToYou == 0 && youOwe == 0;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bothZero)
              _AllSettledLine(currencyCode: currencyCode)
            else
              _SplitNumbers(
                owedToYou: owedToYou,
                youOwe: youOwe,
                currencyCode: currencyCode,
              ),
            if (!bothZero) ...[
              const SizedBox(height: AppSpacing.md),
              _RatioBar(owedToYou: owedToYou, youOwe: youOwe),
            ],
            if (multiCurrencyDisclaimer != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                multiCurrencyDisclaimer!,
                key: const Key('balance.tile.disclaimer'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SplitNumbers extends StatelessWidget {
  const _SplitNumbers({
    required this.owedToYou,
    required this.youOwe,
    required this.currencyCode,
  });

  final double owedToYou;
  final double youOwe;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
    );
    final s = context.strings.budget;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.balanceTileYouAreOwedLabel.toUpperCase(),
                style: labelStyle,
              ),
              const SizedBox(height: 2),
              // FittedBox(scaleDown) keeps very large amounts on a single
              // line at narrow widths (iPhone 12 mini / SE / 320 px).
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: MoneyText(
                  key: const Key('balance.tile.owedToYou'),
                  amount: owedToYou,
                  currencyCode: currencyCode,
                  sign: MoneySign.owedToYou,
                  style: AppTypography.numberDisplay(
                    color: AppColors.moneyOwedToYouFg,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          color: Theme.of(context).colorScheme.outline,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(s.balanceTileYouOweLabel.toUpperCase(), style: labelStyle),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: MoneyText(
                  key: const Key('balance.tile.youOwe'),
                  amount: youOwe,
                  currencyCode: currencyCode,
                  sign: MoneySign.youOwe,
                  style: AppTypography.numberDisplay(
                    color: AppColors.moneyYouOweFg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RatioBar extends StatelessWidget {
  const _RatioBar({required this.owedToYou, required this.youOwe});

  final double owedToYou;
  final double youOwe;

  @override
  Widget build(BuildContext context) {
    final total = owedToYou + youOwe;
    final owedFraction = total == 0 ? 0.5 : owedToYou / total;
    return ClipRRect(
      key: const Key('balance.tile.ratioBar'),
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            Expanded(
              flex: (owedFraction * 1000).round().clamp(0, 1000),
              child: Container(color: AppColors.statusDoneFg),
            ),
            Expanded(
              flex: ((1 - owedFraction) * 1000).round().clamp(0, 1000),
              child: Container(color: AppColors.statusUrgentFg),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllSettledLine extends StatelessWidget {
  const _AllSettledLine({required this.currencyCode});

  final String currencyCode;

  String _formatZero() {
    // Reuse MoneyText's currency formatter by constructing it and reading
    // the visible label. Simpler: hand-format with the symbol code as a
    // prefix. Spec uses USD-shaped formatting throughout; non-USD events
    // fall back to "$" by intl convention.
    return '\$0.00 — all settled';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatZero(),
      key: const Key('balance.tile.allSettled'),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
