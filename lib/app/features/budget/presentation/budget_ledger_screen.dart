import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_assets.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/widgets/empty_state_placeholder.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/core/widgets/balance_tile.dart';
import 'package:crewpoint_app/app/core/widgets/screen_header.dart';
import 'package:crewpoint_app/app/core/widgets/skeletons.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/debt_tile.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/ledger_all_settled_chip.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/recent_expense_tile.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Test seam for opening an event-scoped budget screen from a row in
/// the ledger (debt tile or recent-expense tile). Tests inject a
/// capturing callback; production falls through to `context.push`.
typedef OpenEventBudgetCallback =
    void Function(BuildContext context, EventModel event);

/// Cross-event Budget tab — the Financial Ledger. Hero (owed/you-owe),
/// debts breakdown with Settle Up actions, recent expenses feed.
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
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: s.budget.ledgerAppBarTitle),
            Expanded(
              child: uid == null
                  ? EmptyStatePlaceholder(title: s.tasks.signInRequiredTitle)
                  : ref
                        .watch(globalBalanceLedgerProvider(uid))
                        .when(
                          loading: () => ListView(
                            key: const Key('budget.ledger.loading'),
                            children: const [BalanceTileSkeleton()],
                          ),
                          error: (error, stackTrace) {
                            developer.log(
                              'Failed to load budget ledger',
                              name: 'budget.ledger',
                              error: error,
                              stackTrace: stackTrace,
                            );
                            return EmptyStatePlaceholder(
                              title: s.budget.ledgerErrorTitle,
                              subtitle: error.toString(),
                              lottieAsset: AppAssets.lottieError,
                            );
                          },
                          data: (ledger) {
                            return _LedgerBody(
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
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Branches the data emission: adaptive empty state vs ledger body.
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

    // Detect mixed currencies for the disclaimer banner. V1 display
    // default is USD; a non-USD per-row currency triggers the banner.
    final hasMixedCurrency =
        ledger.debts.any((d) => d.currency != 'USD') ||
        ledger.recentExpenses.any((r) => r.event.currency != 'USD');

    return ListView(
      key: const Key('budget.ledger.list'),
      children: [
        BalanceTile(
          key: const Key('budget.balance'),
          owedToYou: ledger.totalOwedToYou,
          youOwe: ledger.totalYouOwe,
          currencyCode: 'USD',
          multiCurrencyDisclaimer: hasMixedCurrency
              ? strings.budget.multiCurrencyDisclaimer
              : null,
        ),
        // Debts section.
        if (ledger.debts.isNotEmpty) ...[
          _SectionHeader(label: strings.budget.ledgerDebtsHeader),
          for (final debt in ledger.debts)
            DebtTile(
              key: Key(
                'budget.ledger.debt.${debt.counterpartyUid}.${debt.event.id}',
              ),
              row: debt,
              onSettleUp: onSettleUp,
            ),
        ] else
          LedgerAllSettledChip(message: strings.budget.ledgerAllSettledMessage),
        // Recent expenses section.
        if (ledger.recentExpenses.isNotEmpty) ...[
          _SectionHeader(label: strings.budget.ledgerRecentExpensesHeader),
          for (final row in ledger.recentExpenses)
            RecentExpenseTile(
              row: row,
              currentUserId: ref.watch(currentUserIdProvider) ?? '',
              onTap: () {
                final cb = onOpenEventBudget;
                if (cb != null) {
                  cb(context, row.event);
                } else {
                  context.push('/dashboard/event/${row.event.id}/budget');
                }
              },
            ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Adaptive empty-state copy: with events → "Open Dashboard"; zero
/// events → "Create an event".
class _LedgerEmptyState extends ConsumerWidget {
  const _LedgerEmptyState({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasEvents = ref
        .watch(dashboardEventsProvider)
        .maybeWhen(data: (events) => events.isNotEmpty, orElse: () => false);

    return EmptyStatePlaceholder(
      title: strings.budget.ledgerEmptyTitle,
      subtitle: hasEvents
          ? strings.budget.ledgerEmptySubtitle
          : strings.budget.ledgerEmptyNoEventsSubtitle,
      ctaLabel: hasEvents
          ? strings.tasks.openDashboardCta
          : strings.tasks.createFromDashboardCta,
      onCta: () => context.go(AppRoutes.dashboard),
    );
  }
}
