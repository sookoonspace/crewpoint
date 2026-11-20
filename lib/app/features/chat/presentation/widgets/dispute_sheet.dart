import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// Bottom sheet asking the payer or payee to either confirm or dispute a
/// recorded settlement. Pure presentation — caller owns the side effects.
class DisputeSheet extends StatelessWidget {
  const DisputeSheet({
    super.key,
    required this.summary,
    this.onDispute,
    this.closedAfterDays,
  });

  /// Short human-readable line e.g. "You settled \$25 with Alex".
  final String summary;

  /// Fires when the user picks "Dispute". Cancel just closes the sheet.
  final VoidCallback? onDispute;

  /// When set, the dispute window has closed: this explains why instead of
  /// offering the dispute.
  final int? closedAfterDays;

  static Future<void> show({
    required BuildContext context,
    required String summary,
    VoidCallback? onDispute,
    int? closedAfterDays,
  }) {
    return showCpSheet<void>(
      context: context,
      title: context.strings.chat.settlementLabel,
      builder: (_) => DisputeSheet(
        summary: summary,
        onDispute: onDispute,
        closedAfterDays: closedAfterDays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.chat;
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: cp.space.lg,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: cp.space.md,
          children: [
            Icon(
              CpIcons.actionSwap,
              size: cp.sizes.iconMd,
              color: cp.colors.done,
            ),
            Expanded(
              child: Text(
                summary,
                style: cp.type.bodyLarge.copyWith(color: cp.colors.text),
              ),
            ),
          ],
        ),
        if (closedAfterDays == null)
          Text(strings.disputeExplain, style: muted)
        else
          Text(
            strings.disputeWindowClosed(closedAfterDays!),
            key: const Key('chat.dispute.closed'),
            style: muted,
          ),
        CpButton(
          key: const Key('chat.dispute.cancel'),
          label: strings.disputeKeep,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (closedAfterDays == null)
          CpButton.destructive(
            key: const Key('chat.dispute.confirm'),
            label: strings.disputeConfirm,
            expand: true,
            onPressed: () {
              Navigator.of(context).pop();
              onDispute?.call();
            },
          ),
      ],
    );
  }
}
