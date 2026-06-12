import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Small sage-tinted pill rendered next to an expense row when the
/// expense was logged with the "Donate this cost" toggle on.
///
/// Donation-mode expenses leave every member's balance at zero (the
/// payer absorbs the cost), so without a visible cue a row reads as
/// indistinguishable from a regular cost-shared expense whose splits
/// happen to be settled — flagged in the 2026-06-08 iPhone 12 mini
/// QA pass (`Budget_detail_screen.PNG`).
///
/// Both `RecentExpenseTile` (global Budget tab) and `ExpenseTile`
/// (per-event Budget detail) paint this so the cue is consistent
/// across the two surfaces.
class DonatedPill extends StatelessWidget {
  const DonatedPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('budget.expense.donatedPill'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Donated',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.sage,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
