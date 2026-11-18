import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/cp_card.dart';
import 'package:crewpoint_app/app/core/design/components/cp_progress_ring.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// A figure at a glance: a small label with its icon, a large value and an
/// optional caption, such as People · 148 · 41 families. With [progress]
/// the value sits beside a [CpProgressRing].
class CpStatCard extends StatelessWidget {
  const CpStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.progress,
    this.progressLabel,
    this.onTap,
  }) : assert(
         progress == null || progressLabel != null,
         'A ring needs a label for screen readers.',
       );

  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  /// From 0 to 1, drawn as a ring beside the value.
  final double? progress;
  final String? progressLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final valueText = Text(
      value,
      style: cp.type.stat.copyWith(color: cp.colors.text),
    );
    final card = CpCard(
      onTap: onTap,
      semanticLabel: [label, value, ?caption].join(', '),
      padding: EdgeInsets.all(cp.space.md),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: cp.sizes.statMinHeight - 2 * cp.space.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: cp.space.xs + 2,
          children: [
            Row(
              spacing: cp.space.xs + 2,
              children: [
                Icon(
                  icon,
                  size: cp.sizes.iconXs + 1,
                  color: cp.colors.textMuted,
                ),
                Flexible(
                  child: Text(
                    label,
                    style: cp.type.labelSmall.copyWith(
                      color: cp.colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (progress == null)
              valueText
            else
              Row(
                spacing: cp.space.sm,
                children: [
                  CpProgressRing(
                    value: progress!,
                    semanticLabel: progressLabel!,
                  ),
                  Flexible(child: valueText),
                ],
              ),
            if (caption != null)
              Text(
                caption!,
                style: cp.type.labelSmall.copyWith(color: cp.colors.textMuted),
              ),
          ],
        ),
      ),
    );
    return onTap == null ? MergeSemantics(child: card) : card;
  }
}

/// Stat cards side by side, as many to a row as fit: three on a phone at
/// normal text, fewer as text grows, so a value never breaks mid-word.
class CpStatGrid extends StatelessWidget {
  const CpStatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    // The narrowest a stat card reads well at normal text.
    final minWidth = cp.sizes.statMinHeight * scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit =
            ((constraints.maxWidth + cp.space.sm) / (minWidth + cp.space.sm))
                .floor();
        final columns = fit.clamp(1, children.length);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: cp.space.sm,
          children: [
            for (var start = 0; start < children.length; start += columns)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: cp.space.sm,
                  children: [
                    for (var i = start; i < start + columns; i++)
                      Expanded(
                        child: i < children.length
                            ? children[i]
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
