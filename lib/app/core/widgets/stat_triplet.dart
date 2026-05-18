import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/app_typography.dart';

/// One cell in a [StatTriplet]. `value` is nullable so the row can render
/// a "—" placeholder while the underlying provider is still loading.
class StatCell {
  const StatCell({required this.value, required this.label});
  final String? value;
  final String label;
}

/// Three centred stat cells separated by thin vertical dividers.
/// Used on Profile: "{Events count} | {Tasks count} | {Owed total}".
///
/// Exactly 3 cells expected; enforced in [build] (not in the constructor)
/// so the widget can be `const`.
class StatTriplet extends StatelessWidget {
  const StatTriplet({super.key, required this.cells});

  final List<StatCell> cells;

  @override
  Widget build(BuildContext context) {
    assert(cells.length == 3, 'StatTriplet requires exactly 3 cells');
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: _Cell(cells[0])),
            const _Divider(),
            Expanded(child: _Cell(cells[1])),
            const _Divider(),
            Expanded(child: _Cell(cells[2])),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.cell);

  final StatCell cell;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          cell.value ?? '—',
          style: AppTypography.numberDisplay(
            color: AppColors.charcoal,
          ).copyWith(fontSize: 22),
        ),
        const SizedBox(height: 2),
        Text(
          cell.label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.darkGrey),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: AppColors.lightGrey,
    );
  }
}
