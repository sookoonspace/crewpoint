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

/// Single-select pill bar.
///
/// Default layout (`equalWidth: false`) wraps the row in a horizontally
/// scrollable list so labels can breathe at any width — the safe choice for
/// 4+ segments or for screens that will see translated labels (e.g., Spanish
/// "En progreso" is ~6× the width of English "Doing"). Tapping the active
/// pill is a no-op.
///
/// Opt-in `equalWidth: true` is for short, fixed 2–3 segment bars (e.g.,
/// Dashboard's Upcoming/Past). It measures natural pill widths via
/// [TextPainter] and only distributes pills evenly via [Expanded] when they
/// fit in the viewport — otherwise it transparently falls back to the
/// scrolling layout, so labels are never crushed.
class SegmentedFilterBar<T> extends StatelessWidget {
  const SegmentedFilterBar({
    super.key,
    required this.selected,
    required this.segments,
    required this.onChanged,
    this.equalWidth = false,
  });

  final T selected;
  final List<SegmentedFilterSegment<T>> segments;
  final ValueChanged<T> onChanged;

  /// When `true`, attempt to distribute pills evenly across the viewport via
  /// `Expanded`. Falls back to the default scrolling layout when measured
  /// content overflows the available width. Default `false`.
  final bool equalWidth;

  void _handleTap(SegmentedFilterSegment<T> segment) {
    if (segment.value == selected) return;
    onChanged(segment.value);
  }

  @override
  Widget build(BuildContext context) {
    if (equalWidth) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelStyle = Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);
            final natural = _estimateContentWidth(labelStyle);
            if (natural <= constraints.maxWidth) {
              return Row(
                children: [
                  for (var i = 0; i < segments.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i == segments.length - 1 ? 0 : AppSpacing.xs,
                        ),
                        child: _Pill<T>(
                          segment: segments[i],
                          isActive: segments[i].value == selected,
                          onTap: () => _handleTap(segments[i]),
                        ),
                      ),
                    ),
                ],
              );
            }
            return _scrollRow();
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: _scrollRow(),
    );
  }

  Widget _scrollRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final segment in segments)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _Pill<T>(
                segment: segment,
                isActive: segment.value == selected,
                onTap: () => _handleTap(segment),
              ),
            ),
        ],
      ),
    );
  }

  /// Sum of measured pill widths plus inter-pill spacing. Pill width is
  /// the rendered label (and optional count) plus the fixed horizontal
  /// padding + 1 px border per side.
  double _estimateContentWidth(TextStyle? labelStyle) {
    const horizontalPad = AppSpacing.lg * 2;
    const borderPx = 2;
    const countGap = 6.0;
    var total = 0.0;
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final labelWidth = _measureText(seg.label, labelStyle);
      var pillWidth = horizontalPad + borderPx + labelWidth;
      if (seg.count != null) {
        pillWidth += countGap + _measureText('${seg.count}', labelStyle);
      }
      total += pillWidth;
      if (i != segments.length - 1) {
        total += AppSpacing.xs;
      }
    }
    return total;
  }

  double _measureText(String text, TextStyle? style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width;
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
    final colors = Theme.of(context).colorScheme;
    final bg = isActive ? colors.primary : colors.surfaceContainerHighest;
    final fg = isActive ? colors.onPrimary : colors.onSurface;
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
            Flexible(
              child: Text(
                segment.label,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
