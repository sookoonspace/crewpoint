import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Single-select toggle chip with a reserved leading-icon slot so its
/// width stays constant across selected / unselected.
///
/// Material's `FilterChip` shows a leading ✓ on selection and grows
/// horizontally to fit it, jittering chip widths as the user toggles —
/// flagged in the 2026-06-11 iPhone 12 mini QA pass (event_tasks_screen
/// filter chips + Status/People/Due segmented control). This widget
/// always reserves [_reservedSlotWidth] px of leading space; selection
/// state just flips ✓ visibility, so chip widths are identical for the
/// same label.
class ReservedCheckmarkChip extends StatelessWidget {
  const ReservedCheckmarkChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.selectedColor,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  /// Background tint when [selected]. Defaults to
  /// `Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)` —
  /// matches the sage/terracotta `FilterChip.selectedColor` pattern the
  /// Tasks filter bar uses today.
  final Color? selectedColor;

  /// `IconTheme.iconSize` defaults to 18 on the project's theme; +
  /// `AppSpacing.xs` gap to the label = 22 px reserved.
  static const double _reservedSlotWidth = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Use onSurface in BOTH states — selectedColor is always a faded
    // tint (e.g. sage @ 25 % alpha) sitting on top of `surface`, so the
    // standard onSurface text reads well over both backgrounds in
    // either light or dark theme. The earlier `colors.onPrimary` branch
    // resolved to `AppColors.charcoalDark` under dark mode, giving
    // dark-on-dark-tint = invisible (2026-06-11 follow-up).
    final fg = colors.onSurface;
    final bg = selected
        ? (selectedColor ?? colors.primary.withValues(alpha: 0.25))
        : colors.surfaceContainerHighest;
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w600);

    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _reservedSlotWidth,
              child: Visibility(
                visible: selected,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Icon(Icons.check, size: 18, color: fg),
              ),
            ),
            Flexible(
              child: Text(
                label,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
