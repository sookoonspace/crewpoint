import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/donated_pill.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/receipt_viewer.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

enum _Action { edit, delete }

/// One expense (Spec #186): the amount, who paid and when, how it is
/// shared, and the receipt. A settlement shows the green Paid chip. Pure
/// presentation: the parent loads names and saves, and passes only the
/// callbacks the viewer may use. Settlements are never edited here (they
/// are disputed from chat).
class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({
    super.key,
    required this.expense,
    required this.event,
    required this.currencySymbol,
    this.payerName,
    this.payeeName,
    this.mine = false,
    this.onEdit,
    this.onDelete,
    this.onBack,
  });

  final ExpenseModel expense;
  final EventModel event;
  final String currencySymbol;

  /// The payer's name, read by the parent (Req 43a).
  final String? payerName;

  /// For a settlement, who was paid.
  final String? payeeName;

  /// Whether the viewer paid it.
  final bool mine;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Back, or closing the expense beside the list. Pops by default.
  final VoidCallback? onBack;

  String _money(double amount) => '$currencySymbol${amount.toStringAsFixed(2)}';

  Future<void> _openMenu(BuildContext context, String title) async {
    final s = context.strings.budget;
    final canEdit = onEdit != null && !expense.isPayment;
    final id = expense.id;
    final action = await showCpSheet<_Action>(
      context: context,
      title: title,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            if (canEdit)
              CpListRow(
                key: Key('budget.expense.$id.edit'),
                leading: const _MenuIcon(CpIcons.actionEdit),
                title: s.edit,
                trailing: const SizedBox(),
                onTap: () => Navigator.of(sheet).pop(_Action.edit),
              ),
            if (onDelete != null)
              CpListRow(
                key: Key('budget.expense.$id.delete'),
                leading: const _MenuIcon(CpIcons.actionDelete, danger: true),
                title: s.delete,
                trailing: const SizedBox(),
                onTap: () => Navigator.of(sheet).pop(_Action.delete),
              ),
          ],
        ),
      ),
    );
    switch (action) {
      case _Action.edit:
        onEdit?.call();
      case _Action.delete:
        onDelete?.call();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.budget;
    final picker = context.strings.memberPicker;
    final payer = mine ? s.youCapital : (payerName ?? '');
    final title = expense.isPayment
        ? s.paid(payer, payeeName ?? '')
        : (expense.description ?? s.expenseFallback);
    final created = expense.createdAt;
    final menu = (onEdit != null && !expense.isPayment) || onDelete != null;

    // Who shares it: no splits saved means everyone.
    final shares = expense.splits.length;
    final everyone =
        shares == 0 ||
        (shares == event.memberIds.length &&
            expense.splits.every((x) => event.memberIds.contains(x.userId)));
    final count = shares == 0 ? event.memberIds.length : shares;
    final receipt = expense.receiptPath;

    final facts = <Widget>[
      CpListRow(
        key: const Key('budget.expense.detail.payer'),
        leading: CpAvatar(name: payerName ?? payer),
        title: s.paidByLabel,
        subtitle: payer,
      ),
      if (created != null)
        CpListRow(
          key: const Key('budget.expense.detail.date'),
          title: s.dateLabel,
          subtitle: DateFormat.yMMMd().format(event.inZone(created)),
        ),
      if (expense.isPayment)
        CpListRow(
          key: const Key('budget.expense.detail.settlement'),
          title: s.settlementLabel,
          subtitle: s.paid(payer, payeeName ?? ''),
          trailing: CpStatusChip(status: CpStatus.done, label: s.paidChip),
        )
      else if (!expense.isDonation)
        CpListRow(
          key: const Key('budget.expense.detail.split'),
          title: s.splitLabel,
          // One line of text, so nothing breaks mid-word at large sizes.
          subtitle: [
            everyone ? picker.splitEveryone(count) : picker.splitChosen(count),
            if (count > 0) s.eachShare(_money(expense.amount / count)),
          ].join(' · '),
        ),
      if (receipt != null && receipt.isNotEmpty)
        CpListRow(
          key: const Key('budget.expense.receipt.view'),
          leading: ClipRRect(
            borderRadius: cp.radii.sm,
            child: Image.network(
              receipt,
              width: cp.sizes.iconTile,
              height: cp.sizes.iconTile,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                CpIcons.imageBroken,
                size: cp.sizes.iconMd,
                color: cp.colors.textMuted,
              ),
            ),
          ),
          title: s.receiptLabel,
          subtitle: s.viewReceipt,
          onTap: () => ReceiptViewer.show(context: context, imageUrl: receipt),
        ),
    ];

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: title,
        leadingKey: const Key('budget.expense.back'),
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: onBack ?? () => Navigator.of(context).maybePop(),
        actions: [
          if (menu)
            CpTopBarAction(
              key: Key('budget.expense.${expense.id}.overflow'),
              icon: CpIcons.actionMore,
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              onPressed: () => _openMenu(context, title),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.sm,
          cp.space.lg,
          cp.space.xxl,
        ),
        child: ContentMaxWidth(
          key: const Key('budget.expense.detail'),
          maxWidth: cp.sizes.phoneColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.lg,
            children: [
              CpCard(
                padding: EdgeInsets.all(cp.space.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: cp.space.sm,
                  children: [
                    Text(
                      _money(expense.amount),
                      key: const Key('budget.expense.detail.amount'),
                      style: cp.type.displaySmall.copyWith(
                        color: cp.colors.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (!expense.isPayment)
                      Text(
                        title,
                        style: cp.type.bodyLarge.copyWith(
                          color: cp.colors.textMuted,
                        ),
                      ),
                    if (expense.isDonation) const DonatedPill(),
                    if (expense.isPayment)
                      CpStatusChip(status: CpStatus.done, label: s.paidChip),
                  ],
                ),
              ),
              CpCard(child: CpRowGroup(children: facts)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A sheet row's icon; red for Delete.
class _MenuIcon extends StatelessWidget {
  const _MenuIcon(this.icon, {this.danger = false});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Icon(
      icon,
      size: cp.sizes.iconMd,
      color: danger ? cp.colors.overdue : cp.colors.textMuted,
    );
  }
}
