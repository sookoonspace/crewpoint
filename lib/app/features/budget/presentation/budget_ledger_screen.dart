import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/debt_tile.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/recent_expense_tile.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Test seam for opening an event's Budget from a row in the ledger.
/// Tests inject a capturing callback; production falls through to
/// `context.push`.
typedef OpenEventBudgetCallback =
    void Function(BuildContext context, EventModel event);

/// The Budget tab across events (Spec #186): what you are owed and owe in
/// each currency, whom you owe with Settle Up, and recent expenses.
class BudgetLedgerScreen extends ConsumerWidget {
  const BudgetLedgerScreen({
    super.key,
    this.onOpenEventBudget,
    this.onSettleUp,
  });

  final OpenEventBudgetCallback? onOpenEventBudget;

  /// Optional test seam — production wiring uses
  /// `settleUpControllerProvider.handleSettleUp`.
  final OnSettleUp? onSettleUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: context.cp.colors.background,
      appBar: CpTopBar(title: s.budget.ledgerAppBarTitle),
      body: uid == null
          ? CpEmptyState(icon: CpIcons.lock, title: s.tasks.signInRequiredTitle)
          : ref
                .watch(globalBalanceLedgerProvider(uid))
                .when(
                  loading: () => CpLoadingState.rows(
                    key: const Key('budget.ledger.loading'),
                    semanticLabel: s.budget.ledgerAppBarTitle,
                  ),
                  error: (error, stackTrace) {
                    developer.log(
                      'Failed to load budget ledger',
                      name: 'budget.ledger',
                      error: error,
                      stackTrace: stackTrace,
                    );
                    return CpErrorState(
                      key: const Key('budget.ledger.error'),
                      title: s.budget.ledgerErrorTitle,
                      retryLabel: s.people.retry,
                      retryKey: const Key('budget.ledger.retry'),
                      onRetry: () =>
                          ref.invalidate(globalBalanceLedgerProvider(uid)),
                    );
                  },
                  data: (ledger) => _LedgerBody(
                    ledger: ledger,
                    strings: s,
                    onOpenEventBudget: onOpenEventBudget,
                    onSettleUp:
                        onSettleUp ??
                        (ctx, row) {
                          unawaited(
                            ref
                                .read(settleUpControllerProvider)
                                .handleSettleUp(ctx, row),
                          );
                        },
                  ),
                ),
    );
  }
}

/// The ledger, or the empty state when there is nothing to show.
class _LedgerBody extends ConsumerWidget {
  const _LedgerBody({
    required this.ledger,
    required this.strings,
    this.onOpenEventBudget,
    this.onSettleUp,
  });

  final LedgerSummary ledger;
  final AppStrings strings;
  final OpenEventBudgetCallback? onOpenEventBudget;
  final OnSettleUp? onSettleUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ledger.debts.isEmpty && ledger.recentExpenses.isEmpty) {
      return _LedgerEmptyState(strings: strings);
    }

    final cp = context.cp;
    final totals = ledger.totalsByCurrency;
    final me = ref.watch(currentUserIdProvider) ?? '';

    return ContentMaxWidth(
      maxWidth: cp.sizes.phoneColumn,
      child: ListView(
        key: const Key('budget.ledger.list'),
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.sm,
          cp.space.lg,
          cp.space.xxl,
        ),
        children: [
          // One card per currency, because amounts in different currencies
          // cannot be added.
          if (totals.isEmpty)
            _BalanceCard(
              key: const Key('budget.balance'),
              owedToYou: 0,
              youOwe: 0,
              currencyCode: ledger.recentExpenses.isEmpty
                  ? 'USD'
                  : ledger.recentExpenses.first.event.currency,
            ),
          for (final (index, entry) in totals.entries.indexed)
            Padding(
              padding: EdgeInsets.only(bottom: cp.space.md),
              child: _BalanceCard(
                key: index == 0
                    ? const Key('budget.balance')
                    : Key('budget.balance.${entry.key}'),
                owedToYou: entry.value.owedToYou,
                youOwe: entry.value.youOwe,
                currencyCode: entry.key,
              ),
            ),
          if (ledger.debts.isNotEmpty) ...[
            SizedBox(height: cp.space.md),
            CpSectionHeader(
              title: strings.budget.ledgerDebtsHeader,
              trailingText: '${ledger.debts.length}',
            ),
            SizedBox(height: cp.space.sm),
            CpCard(
              child: CpRowGroup(
                children: [
                  for (final debt in ledger.debts)
                    DebtTile(
                      key: Key(
                        'budget.ledger.debt.${debt.counterpartyUid}.${debt.event.id}',
                      ),
                      row: debt,
                      onSettleUp: onSettleUp,
                    ),
                ],
              ),
            ),
          ],
          if (ledger.recentExpenses.isNotEmpty) ...[
            SizedBox(height: cp.space.lg),
            CpSectionHeader(title: strings.budget.ledgerRecentExpensesHeader),
            SizedBox(height: cp.space.sm),
            CpCard(
              child: CpRowGroup(
                children: [
                  for (final row in ledger.recentExpenses)
                    RecentExpenseTile(
                      row: row,
                      currentUserId: me,
                      onTap: () {
                        final cb = onOpenEventBudget;
                        if (cb != null) {
                          cb(context, row.event);
                        } else {
                          context.push(
                            '/dashboard/event/${row.event.id}/budget/'
                            '${row.expense.id}',
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What you are owed and what you owe in one currency, or "You are all
/// settled" when both are zero. Owing shows amber with its icon (Req 10).
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    super.key,
    required this.owedToYou,
    required this.youOwe,
    required this.currencyCode,
  });

  final double owedToYou;
  final double youOwe;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.budget;
    final settled = owedToYou.abs() < 0.005 && youOwe.abs() < 0.005;
    final big = cp.type.headlineSmall.copyWith(
      color: cp.colors.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget side(String label, Widget value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.xs,
      children: [
        Text(
          label.toUpperCase(),
          style: cp.type.labelMedium.copyWith(color: cp.colors.textMuted),
        ),
        value,
      ],
    );
    return CpCard(
      padding: EdgeInsets.all(cp.space.xl),
      child: settled
          ? Text(
              s.allSettled,
              key: const Key('balance.tile.allSettled'),
              style: cp.type.titleMedium.copyWith(color: cp.colors.text),
            )
          : Wrap(
              spacing: cp.space.xxl,
              runSpacing: cp.space.lg,
              children: [
                side(
                  s.ledgerHeroOwedToYouLabel,
                  Text(
                    MoneyText.format(owedToYou, currencyCode),
                    key: const Key('balance.tile.owedToYou'),
                    style: big,
                  ),
                ),
                side(
                  s.ledgerHeroYouOweLabel,
                  youOwe.abs() < 0.005
                      ? Text(
                          MoneyText.format(0, currencyCode),
                          key: const Key('balance.tile.youOwe'),
                          style: big,
                        )
                      : CpStatusChip(
                          key: const Key('balance.tile.youOwe'),
                          status: CpStatus.due,
                          label: MoneyText.format(youOwe, currencyCode),
                        ),
                ),
              ],
            ),
    );
  }
}

/// With events, the action opens Home; with none, it asks to create one.
class _LedgerEmptyState extends ConsumerWidget {
  const _LedgerEmptyState({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasEvents = ref
        .watch(dashboardEventsProvider)
        .maybeWhen(data: (events) => events.isNotEmpty, orElse: () => false);

    return CpEmptyState(
      key: const Key('budget.ledger.empty'),
      icon: CpIcons.navBudget,
      title: strings.budget.ledgerEmptyTitle,
      message: hasEvents
          ? strings.budget.ledgerEmptySubtitle
          : strings.budget.ledgerEmptyNoEventsSubtitle,
      actionLabel: hasEvents
          ? strings.tasks.openDashboardCta
          : strings.tasks.createFromDashboardCta,
      actionKey: const Key('budget.ledger.empty.action'),
      onAction: () => context.go(AppRoutes.dashboard),
    );
  }
}
