import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/donated_pill.dart';

/// One row in the Budget tab's recent expenses across events (Spec #186):
/// who paid, what, which event, the amount and how long ago. Use inside a
/// [CpRowGroup].
class RecentExpenseTile extends StatelessWidget {
  const RecentExpenseTile({
    super.key,
    required this.row,
    required this.currentUserId,
    required this.onTap,
  });

  final RecentExpenseRow row;
  final String currentUserId;
  final VoidCallback onTap;

  /// Relative time ("2h", "yesterday", "Mar 4"); older than 30 days shows
  /// the date (spec req 37).
  String _formatTimestamp(DateTime? when) {
    if (when == null) return '';
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return DateFormat.MMMd().format(row.event.inZone(when));
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.budget;
    final exp = row.expense;
    final payerLabel = exp.payerId == currentUserId
        ? s.youCapital
        : row.payerName;
    final removed = payerLabel == kRemovedMemberPlaceholder;
    final tile = ConstrainedBox(
      constraints: BoxConstraints(minHeight: cp.sizes.rowMinHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: cp.space.lg,
          vertical: cp.space.md,
        ),
        child: Row(
          spacing: cp.space.md,
          children: [
            CpAvatar(
              name: removed ? '?' : payerLabel,
              semanticLabel: payerLabel,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: cp.space.xs / 2,
                children: [
                  Text(
                    exp.description ?? s.someonePaid(payerLabel),
                    style: cp.type.titleSmall.copyWith(color: cp.colors.text),
                  ),
                  Text(
                    row.event.title,
                    style: cp.type.bodySmall.copyWith(
                      color: cp.colors.textMuted,
                    ),
                  ),
                  if (exp.isDonation) const DonatedPill(),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: cp.space.xs / 2,
              children: [
                MoneyText(
                  amount: exp.amount,
                  currencyCode: row.event.currency,
                  style: cp.type.titleSmall.copyWith(color: cp.colors.text),
                ),
                Text(
                  _formatTimestamp(exp.createdAt),
                  style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: Key('budget.ledger.recentExpense.${exp.id}'),
        onTap: onTap,
        child: tile,
      ),
    );
  }
}
