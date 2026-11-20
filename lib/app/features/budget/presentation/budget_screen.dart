import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/layout/cp_list_detail.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/budget_summary.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/large_event.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_tile.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/settle_sheet.dart';

/// The event's Budget (Spec #186): what was spent, your balance with Settle
/// up, everyone's balances, who pays whom, then the expenses. From 840 px
/// the chosen expense ([detail]) sits beside the list ([CpListDetail]);
/// narrower the list shows alone.
///
/// Pure presentation: the parent (`EventBudgetPage`) reads names and
/// balances, and saves.
class BudgetScreen extends StatelessWidget {
  const BudgetScreen({
    super.key,
    required this.expenses,
    required this.memberIds,
    this.currentUserId = '',
    this.currency = 'USD',
    this.canAddExpense = true,
    this.memberNames = const {},
    this.appBarTitle,
    this.onAddExpense,
    this.onOpenExpense,
    this.onRecordPayment,
    this.onExportPdf,
    this.onExportCsv,
    this.onBack,
    this.ledger,
    this.selectedId,
    this.detail,
    this.scrollController,
    this.inZone,
  });

  /// Balances to show instead of working them out from [expenses], for
  /// someone who may not read every expense: their own balance and
  /// transfers from the server (Req 38c).
  final BalanceLedger? ledger;

  final List<ExpenseModel> expenses;
  final List<String> memberIds;

  /// Whose balance and transfers always show in a large event (Req 43a).
  final String currentUserId;
  final String currency;

  /// False once the event is archived, or for Observers and Vendors.
  final bool canAddExpense;
  final Map<String, String> memberNames;

  /// The top bar's title: the event's name, so someone in several events
  /// knows which budget this is. "Budget" when not given.
  final String? appBarTitle;
  final VoidCallback? onAddExpense;

  /// Opens an expense (beside the list from 840 px).
  final ValueChanged<ExpenseModel>? onOpenExpense;
  final void Function(Settlement settlement)? onRecordPayment;
  final VoidCallback? onExportPdf;
  final VoidCallback? onExportCsv;
  final VoidCallback? onBack;

  /// The expense open beside the list, from the route.
  final String? selectedId;
  final Widget? detail;
  final ScrollController? scrollController;

  /// Turns a time into the event's zone for dates.
  final DateTime Function(DateTime)? inZone;

  String _nameOf(String uid) => memberIds.contains(uid)
      ? (memberNames[uid] ?? uid)
      : resolveMemberName(uid: uid, memberNames: memberNames);

  void _settle(BuildContext context, Settlement settlement, String symbol) {
    final record = onRecordPayment;
    if (record != null) {
      record(settlement);
      return;
    }
    // Screens without the pay flow still show what to pay.
    SettleSheet.show(
      context: context,
      settlement: settlement,
      currencySymbol: symbol,
      fromName: memberNames[settlement.fromUserId],
      toName: memberNames[settlement.toUserId],
    );
  }

  Future<void> _export(BuildContext context) async {
    final s = context.strings.budget;
    final pick = await showCpSheet<String>(
      context: context,
      title: s.exportTooltip,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            if (onExportPdf != null)
              CpListRow(
                key: const Key('budget.export.pdf'),
                title: s.exportPdf,
                trailing: const SizedBox(),
                onTap: () => Navigator.of(sheet).pop('pdf'),
              ),
            if (onExportCsv != null)
              CpListRow(
                key: const Key('budget.export.csv'),
                title: s.exportCsv,
                trailing: const SizedBox(),
                onTap: () => Navigator.of(sheet).pop('csv'),
              ),
          ],
        ),
      ),
    );
    switch (pick) {
      case 'pdf':
        onExportPdf?.call();
      case 'csv':
        onExportCsv?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.budget;
    final roles = context.strings.roles;
    final ledger =
        this.ledger ??
        BalanceLedger.calculate(expenses: expenses, memberIds: memberIds);
    final symbol = currencySymbolFor(currency);
    String money(double amount) => '$symbol${amount.toStringAsFixed(2)}';
    // Past 50 members, only you and the largest balances and transfers
    // show, so a large event stays quick (Req 43a).
    final shownBalances = shownBalanceUids(
      ledger.netBalances,
      me: currentUserId,
      memberCount: memberIds.length,
    );
    final settlements = shownSettlements(
      ledger.settlements,
      me: currentUserId,
      memberCount: memberIds.length,
    );
    final trimmed = splitNeedsChoosing(memberIds.length);
    final shared = memberIds.length > 1;
    final regularCount = expenses.where((e) => !e.isPayment).length;
    final balances = [
      for (final e in ledger.netBalances.entries)
        if (shownBalances.contains(e.key)) e,
    ]..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    final list = ListView(
      key: const Key('budget.list'),
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        cp.space.lg,
        cp.space.sm,
        cp.space.lg,
        cp.space.xxl,
      ),
      children: [
        _SpentCard(
          total: money(ledger.totalExpenses),
          count: s.expenseCount(regularCount),
        ),
        if (shared) ...[
          SizedBox(height: cp.space.md),
          _YourBalanceCard(
            summary: myBalanceSummary(ledger, currentUserId),
            nameOf: _nameOf,
            money: money,
            onSettle: (settlement) => _settle(context, settlement, symbol),
          ),
        ],
        if (shared && balances.isNotEmpty) ...[
          SizedBox(height: cp.space.lg),
          CpSectionHeader(
            title: s.balancesHeading,
            trailingText: '${balances.length}',
          ),
          SizedBox(height: cp.space.sm),
          if (trimmed) ...[
            Text(
              s.largestShown(largeEventTopBalances),
              key: const Key('budget.balances.trimmed'),
              style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
            ),
            SizedBox(height: cp.space.sm),
          ],
          CpCard(
            child: CpRowGroup(
              children: [
                for (final entry in balances)
                  _BalanceRow(
                    key: Key('budget.balance.${entry.key}'),
                    name: _nameOf(entry.key),
                    balance: entry.value,
                    amount: money(entry.value.abs()),
                  ),
              ],
            ),
          ),
        ],
        if (settlements.isNotEmpty) ...[
          SizedBox(height: cp.space.lg),
          CpSectionHeader(title: s.settleUpHeading),
          SizedBox(height: cp.space.sm),
          CpCard(
            child: CpRowGroup(
              children: [
                for (final settlement in settlements)
                  CpListRow(
                    title: s.pays(
                      _nameOf(settlement.fromUserId),
                      _nameOf(settlement.toUserId),
                    ),
                    subtitle: money(settlement.amount),
                    trailing: CpButton.text(
                      key: Key('budget.settle.${settlement.toUserId}'),
                      label: s.settle,
                      onPressed: () => _settle(context, settlement, symbol),
                    ),
                  ),
              ],
            ),
          ),
        ],
        SizedBox(height: cp.space.lg),
        CpSectionHeader(
          title: s.expensesHeading,
          trailingText: expenses.isEmpty ? null : '${expenses.length}',
        ),
        SizedBox(height: cp.space.sm),
        if (expenses.isEmpty)
          CpEmptyState(
            key: const Key('budget.expenses.empty'),
            icon: CpIcons.receipt,
            title: s.noExpenses,
            message: canAddExpense ? s.noExpensesHelp : null,
          )
        else
          CpCard(
            child: CpRowGroup(
              children: [
                for (final e in expenses)
                  Builder(
                    builder: (row) => ExpenseTile(
                      expense: e,
                      currencySymbol: symbol,
                      payerName: _nameOf(e.payerId),
                      payeeName: e.isPayment && e.splits.isNotEmpty
                          ? (e.splits.first.userId == currentUserId
                                ? s.you
                                : _nameOf(e.splits.first.userId))
                          : null,
                      mine: e.payerId == currentUserId,
                      selected: e.id == selectedId,
                      inZone: inZone,
                      // Asks first when the open expense has unsaved edits.
                      onTap: onOpenExpense == null
                          ? null
                          : () => CpListDetail.select(
                              row,
                              () => onOpenExpense!(e),
                            ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: appBarTitle ?? s.title,
        leadingKey: const Key('budget.back'),
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: onBack,
        actions: [
          if (onExportPdf != null || onExportCsv != null)
            CpTopBarAction(
              key: const Key('budget.export.menu'),
              icon: CpIcons.actionShare,
              tooltip: s.exportTooltip,
              onPressed: () => _export(context),
            ),
          if (canAddExpense)
            CpTopBarAction(
              key: const Key('budget.expense.create'),
              icon: CpIcons.actionAdd,
              tooltip: s.addExpenseTitle,
              primary: true,
              onPressed: onAddExpense ?? () {},
            ),
        ],
      ),
      body: CpListDetail(
        list: ContentMaxWidth(maxWidth: cp.sizes.phoneColumn, child: list),
        detail: detail,
        placeholder: context.strings.nav.selectToSee(s.expenseWord),
        unsavedText: CpUnsavedText(
          title: roles.discardTitle,
          body: roles.discardBody,
          keep: roles.keepEditing,
          discard: roles.discard,
        ),
      ),
    );
  }
}

/// "Spent $4,320" and how many expenses.
class _SpentCard extends StatelessWidget {
  const _SpentCard({required this.total, required this.count});

  final String total;
  final String count;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return CpCard(
      key: const Key('budget.total'),
      padding: EdgeInsets.all(cp.space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: cp.space.xs,
        children: [
          Text(
            context.strings.budget.spentLabel.toUpperCase(),
            style: cp.type.labelMedium.copyWith(color: cp.colors.textMuted),
          ),
          Text(
            total,
            style: cp.type.displaySmall.copyWith(
              color: cp.colors.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            count,
            style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Your balance: "You are owed $120", who owes you or whom you owe, and
/// Settle up when you owe someone.
class _YourBalanceCard extends StatelessWidget {
  const _YourBalanceCard({
    required this.summary,
    required this.nameOf,
    required this.money,
    required this.onSettle,
  });

  final ({double net, List<Settlement> owedToMe, List<Settlement> iOwe})
  summary;
  final String Function(String uid) nameOf;
  final String Function(double amount) money;
  final ValueChanged<Settlement> onSettle;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.budget;
    final net = summary.net;
    final headline = net > 0.005
        ? s.youAreOwed(money(net))
        : net < -0.005
        ? s.youOwe(money(-net))
        : s.allSettled;
    final who = [
      for (final x in summary.owedToMe.take(2))
        s.owesYou(nameOf(x.fromUserId), money(x.amount)),
      for (final x in summary.iOwe.take(2))
        s.youOweName(nameOf(x.toUserId), money(x.amount)),
    ].join(' · ');
    return CpCard(
      key: const Key('budget.yourBalance'),
      padding: EdgeInsets.all(cp.space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.sm,
        children: [
          Text(
            s.yourBalanceLabel.toUpperCase(),
            style: cp.type.labelMedium.copyWith(color: cp.colors.textMuted),
          ),
          Text(
            headline,
            key: const Key('budget.yourBalance.headline'),
            style: cp.type.headlineSmall.copyWith(color: cp.colors.text),
          ),
          if (who.isNotEmpty)
            Text(
              who,
              style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
            ),
          if (summary.iOwe.isNotEmpty) ...[
            SizedBox(height: cp.space.xs),
            CpButton(
              key: const Key('budget.yourBalance.settle'),
              label: s.settleUp,
              icon: CpIcons.actionSwap,
              expand: true,
              onPressed: () => onSettle(summary.iOwe.first),
            ),
          ],
        ],
      ),
    );
  }
}

/// One person's balance: what they are owed plainly, what they owe as an
/// amber chip, settled as a green one, each with its icon (Req 10).
class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    super.key,
    required this.name,
    required this.balance,
    required this.amount,
  });

  final String name;
  final double balance;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.budget;
    final owed = balance > 0.005;
    final owes = balance < -0.005;
    final value = owes
        ? CpStatusChip(status: CpStatus.due, label: amount)
        : owed
        ? Text(
            amount,
            style: cp.type.titleSmall.copyWith(
              color: cp.colors.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        : CpStatusChip(status: CpStatus.done, label: s.settled);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: cp.sizes.rowMinHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: cp.space.lg,
          vertical: cp.space.md,
        ),
        // At large text on a narrow row the amount goes under the name, so
        // no word breaks mid-way (Req 45).
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth / scale < 260;
            return MergeSemantics(
              child: Row(
                spacing: cp.space.md,
                children: [
                  if (!stacked) CpAvatar(name: name),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: cp.space.xs / 2,
                      children: [
                        Text(
                          name,
                          style: cp.type.titleSmall.copyWith(
                            color: cp.colors.text,
                          ),
                        ),
                        Text(
                          owed
                              ? s.isOwed
                              : owes
                              ? s.owes
                              : s.settled,
                          style: cp.type.bodySmall.copyWith(
                            color: cp.colors.textMuted,
                          ),
                        ),
                        if (stacked) value,
                      ],
                    ),
                  ),
                  if (!stacked) value,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
