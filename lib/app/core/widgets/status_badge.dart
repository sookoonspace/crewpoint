import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Pill-shaped status label that always pairs an icon with a color, so
/// meaning is never carried by color alone (a11y requirement). Optional
/// trailing count for use as a filter pill.
class StatusBadge extends StatelessWidget {
  const StatusBadge._({
    super.key,
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    this.count,
  });

  const StatusBadge.todo({Key? key, required String label, int? count})
    : this._(
        key: key,
        icon: Icons.radio_button_unchecked,
        label: label,
        foreground: AppColors.statusTodoFg,
        background: AppColors.statusTodoBg,
        count: count,
      );

  const StatusBadge.doing({Key? key, required String label, int? count})
    : this._(
        key: key,
        icon: Icons.play_circle_outline,
        label: label,
        foreground: AppColors.statusDoingFg,
        background: AppColors.statusDoingBg,
        count: count,
      );

  const StatusBadge.done({Key? key, required String label, int? count})
    : this._(
        key: key,
        icon: Icons.check_circle,
        label: label,
        foreground: AppColors.statusDoneFg,
        background: AppColors.statusDoneBg,
        count: count,
      );

  const StatusBadge.urgent({Key? key, required String label, int? count})
    : this._(
        key: key,
        icon: Icons.warning_amber_rounded,
        label: label,
        foreground: AppColors.statusUrgentFg,
        background: AppColors.statusUrgentBg,
        count: count,
      );

  const StatusBadge.info({Key? key, required String label, int? count})
    : this._(
        key: key,
        icon: Icons.info_outline,
        label: label,
        foreground: AppColors.info,
        background: const Color(0x1A74B9FF),
        count: count,
      );

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(label, style: labelStyle),
          if (count != null) ...[
            const SizedBox(width: 4),
            Text('$count', style: labelStyle),
          ],
        ],
      ),
    );
  }
}
