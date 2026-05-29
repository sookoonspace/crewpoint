import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Bottom sheet asking the payer or payee to either confirm or dispute a
/// recorded settlement. Pure presentation — caller owns the side effects.
class DisputeSheet extends StatelessWidget {
  const DisputeSheet({super.key, required this.summary, this.onDispute});

  /// Short human-readable line e.g. "You settled \$25 with Alex".
  final String summary;

  /// Fires when the user picks "Dispute". Cancel just closes the sheet.
  final VoidCallback? onDispute;

  static Future<void> show({
    required BuildContext context,
    required String summary,
    VoidCallback? onDispute,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (_) => DisputeSheet(summary: summary, onDispute: onDispute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.viewPaddingOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: .min,
        spacing: AppSpacing.lg,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Settlement', style: Theme.of(context).textTheme.titleLarge),
          Text(
            summary,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          Text(
            'Disputing will remove this settlement and restore the balance.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          FilledButton(
            key: const Key('chat.dispute.cancel'),
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppColors.sage,
            ),
            child: const Text('All good — keep it'),
          ),
          OutlinedButton(
            key: const Key('chat.dispute.confirm'),
            onPressed: () {
              Navigator.of(context).pop();
              onDispute?.call();
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.terracotta,
              side: const BorderSide(color: AppColors.terracotta),
            ),
            child: const Text('Dispute this settlement'),
          ),
        ],
      ),
    );
  }
}
