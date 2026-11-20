import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/donated_pill.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/receipt_viewer.dart';

/// One expense in the event's Budget list (Spec #186): an icon (or the
/// receipt's thumbnail), what it was, who paid and how it is shared, then
/// the amount and date. A settlement reads "Ravi paid Priya" with the green
/// Paid chip. Use inside a [CpRowGroup]; tapping opens the expense.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    this.currencySymbol = '\$',
    this.payerName,
    this.payeeName,
    this.mine = false,
    this.selected = false,
    this.onTap,
    this.inZone,
  });

  final ExpenseModel expense;
  final String currencySymbol;

  /// The payer's name, once read (Req 43a).
  final String? payerName;

  /// For a settlement, who was paid.
  final String? payeeName;

  /// Whether the viewer paid it ("Paid by you").
  final bool mine;

  /// The expense open beside the list (Req 23).
  final bool selected;
  final VoidCallback? onTap;

  /// Turns the date into the event's day; local by default.
  final DateTime Function(DateTime)? inZone;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.budget;
    final receipt = expense.receiptPath;
    final hasReceipt = receipt != null && receipt.isNotEmpty;
    final payer = mine ? s.you : payerName;
    final title = expense.isPayment
        ? s.paid(mine ? s.youCapital : (payerName ?? ''), payeeName ?? '')
        : (expense.description ?? s.expenseFallback);
    final subtitle = expense.isPayment
        ? s.settlementLabel
        : [
            if (payer != null && payer.isNotEmpty) s.paidBy(payer),
            if (!expense.isDonation && expense.splits.length > 1)
              s.splitWays(expense.splits.length),
          ].join(' · ');
    final created = expense.createdAt;
    final date = created == null
        ? null
        : DateFormat.MMMd().format((inZone ?? (d) => d.toLocal())(created));

    final iconTile = Container(
      width: cp.sizes.iconTile,
      height: cp.sizes.iconTile,
      decoration: BoxDecoration(
        color: cp.colors.accentSoft,
        borderRadius: cp.radii.sm,
      ),
      child: Icon(
        expense.isPayment
            ? CpIcons.actionSwap
            : expense.isDonation
            ? CpIcons.volunteerActivism
            : CpIcons.receipt,
        size: cp.sizes.iconMd,
        color: cp.colors.accent,
      ),
    );

    final leading = hasReceipt
        ? Semantics(
            button: true,
            label: s.viewReceipt,
            child: GestureDetector(
              key: Key('budget.expense.tile.${expense.id}.thumbnail'),
              onTap: () =>
                  ReceiptViewer.show(context: context, imageUrl: receipt),
              child: ClipRRect(
                borderRadius: cp.radii.sm,
                child: Image.network(
                  receipt,
                  width: cp.sizes.iconTile,
                  height: cp.sizes.iconTile,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => iconTile,
                ),
              ),
            ),
          )
        : iconTile;

    final trailing = <Widget>[
      Text(
        '$currencySymbol${expense.amount.toStringAsFixed(2)}',
        key: Key('budget.expense.tile.${expense.id}.amount'),
        style: cp.type.titleSmall.copyWith(
          color: cp.colors.text,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      if (expense.isPayment)
        CpStatusChip(
          key: Key('budget.expense.tile.${expense.id}.paid'),
          status: CpStatus.done,
          label: s.paidChip,
        )
      else if (date != null)
        Text(
          date,
          style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
        ),
    ];
    // At large text on a narrow row the amount goes under the title, so no
    // word breaks mid-way (Req 45).
    final scale = MediaQuery.textScalerOf(context).scale(1);

    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: cp.sizes.rowMinHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: cp.space.lg,
          vertical: cp.space.md,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth / scale < 260;
            return Row(
              spacing: cp.space.md,
              children: [
                if (!stacked) leading,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: cp.space.xs / 2,
                    children: [
                      Text(
                        title,
                        style: cp.type.titleSmall.copyWith(
                          color: cp.colors.text,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: cp.type.bodySmall.copyWith(
                            color: cp.colors.textMuted,
                          ),
                        ),
                      if (expense.isDonation) const DonatedPill(),
                      if (stacked)
                        Wrap(
                          spacing: cp.space.sm,
                          runSpacing: cp.space.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: trailing,
                        ),
                    ],
                  ),
                ),
                if (!stacked)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: cp.space.xs / 2,
                    children: trailing,
                  ),
              ],
            );
          },
        ),
      ),
    );

    return Semantics(
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('budget.expense.tile.${expense.id}'),
          onTap: onTap,
          child: selected
              ? ColoredBox(color: cp.colors.accentSoft, child: row)
              : row,
        ),
      ),
    );
  }
}
