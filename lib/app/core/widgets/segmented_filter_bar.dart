import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

class SegmentedFilterSegment<T> {
  const SegmentedFilterSegment({
    required this.value,
    required this.label,
    this.keyValue,
    this.count,
  });

  final T value;
  final String label;
  final Key? keyValue;
  final int? count;
}

/// Single-select pill bar. Active pill uses charcoal background + white
/// label; inactive pills are surface with charcoal text. Tapping the active
/// pill is a no-op.
class SegmentedFilterBar<T> extends StatelessWidget {
  const SegmentedFilterBar({
    super.key,
    required this.selected,
    required this.segments,
    required this.onChanged,
  });

  final T selected;
  final List<SegmentedFilterSegment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final segment in segments)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: _Pill<T>(
                  segment: segment,
                  isActive: segment.value == selected,
                  onTap: () {
                    if (segment.value == selected) return;
                    onChanged(segment.value);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill<T> extends StatelessWidget {
  const _Pill({
    required this.segment,
    required this.isActive,
    required this.onTap,
  });

  final SegmentedFilterSegment<T> segment;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? AppColors.charcoal : AppColors.white;
    final fg = isActive ? AppColors.white : AppColors.charcoal;
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w600);

    return InkWell(
      key: segment.keyValue,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.lightGrey),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(segment.label, style: labelStyle),
            if (segment.count != null) ...[
              const SizedBox(width: 6),
              Text('${segment.count}', style: labelStyle),
            ],
          ],
        ),
      ),
    );
  }
}
