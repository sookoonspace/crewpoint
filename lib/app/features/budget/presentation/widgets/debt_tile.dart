import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';

/// Settle-up tap callback. Production wires this to
/// `SettleUpController.handleSettleUp`; tests inject a recorder.
typedef OnSettleUp = void Function(BuildContext context, DebtRow row);

/// Someone you owe in one event (Spec #186): their initials, name and the
/// event, the amount as an amber "owed" chip, and Settle Up. Use inside a
/// [CpRowGroup].
class DebtTile extends StatelessWidget {
  const DebtTile({super.key, required this.row, this.onSettleUp});

  final DebtRow row;
  final OnSettleUp? onSettleUp;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final removed = row.counterpartyName == kRemovedMemberPlaceholder;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: cp.space.lg,
        vertical: cp.space.md,
      ),
      child: Row(
        spacing: cp.space.md,
        children: [
          CpAvatar(
            name: removed ? '?' : row.counterpartyName,
            semanticLabel: row.counterpartyName,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: cp.space.xs / 2,
              children: [
                Text(
                  row.counterpartyName,
                  style: cp.type.titleSmall.copyWith(color: cp.colors.text),
                ),
                Text(
                  row.event.title,
                  style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
                ),
                // Owed: amber with its icon (Req 10).
                CpStatusChip(
                  key: Key(
                    'budget.ledger.debt.${row.counterpartyUid}.${row.event.id}.amount',
                  ),
                  status: CpStatus.due,
                  label: MoneyText.format(row.amount, row.currency),
                ),
              ],
            ),
          ),
          CpButton.secondary(
            key: Key(
              'budget.ledger.settleUp.${row.counterpartyUid}.${row.event.id}',
            ),
            label: context.strings.budget.ledgerSettleUpCta,
            onPressed: onSettleUp == null
                ? null
                : () => onSettleUp!(context, row),
          ),
        ],
      ),
    );
  }
}
