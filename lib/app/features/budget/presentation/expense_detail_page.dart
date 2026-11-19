import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/budget_summary.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/expense_detail_screen.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_modal.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Loads one expense and saves through the repository: the route
/// `/event/:eventId/budget/:expenseId`, beside the Budget list from 840 px
/// (Spec #186 Req 23).
///
/// Editing happens in place, so beside the list the form keeps its place
/// and choosing another expense with unsaved edits asks first.
class ExpenseDetailPage extends ConsumerStatefulWidget {
  const ExpenseDetailPage({
    super.key,
    required this.event,
    required this.expenseId,
  });

  final EventModel event;
  final String expenseId;

  @override
  ConsumerState<ExpenseDetailPage> createState() => _ExpenseDetailPageState();
}

class _ExpenseDetailPageState extends ConsumerState<ExpenseDetailPage> {
  bool _editing = false;

  Future<void> _delete(ExpenseModel expense) async {
    final s = context.strings.budget;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => CpDialog(
        title: s.deleteTitle,
        message: s.deleteBody,
        actions: [
          CpButton.text(
            key: const Key('budget.expense.delete.cancel'),
            label: s.cancel,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          CpButton.destructive(
            key: const Key('budget.expense.delete.confirm'),
            label: s.delete,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(expenseRepositoryProvider)
        .deleteExpense(expense.id);
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(s.deleteFailed)));
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final s = context.strings.budget;
    final uid = ref.watch(currentUserIdProvider) ?? '';
    final symbol = currencySymbolFor(event.currency);

    Widget bare(Widget body) => Scaffold(
      appBar: CpTopBar(
        title: s.expenseWord,
        leadingKey: const Key('budget.expense.back'),
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: () => Navigator.of(context).maybePop(),
      ),
      body: body,
    );

    return ref
        .watch(expenseListProvider(event.id))
        .when(
          data: (expenses) {
            final expense = expenses
                .where((e) => e.id == widget.expenseId)
                .firstOrNull;
            if (expense == null) {
              return bare(
                CpEmptyState(
                  key: const Key('budget.expense.notFound'),
                  icon: CpIcons.receipt,
                  title: s.notFound,
                ),
              );
            }
            final payee = expense.isPayment && expense.splits.isNotEmpty
                ? expense.splits.first.userId
                : null;
            // Only the people this expense shows (Req 43a).
            final names =
                ref
                    .watch(
                      peopleByIdProvider(
                        PeopleKey(event.id, [expense.payerId, ?payee]),
                      ),
                    )
                    .value ??
                const {};
            String nameOf(String id) => resolveMemberName(
              uid: id,
              memberNames: {
                for (final e in names.entries)
                  e.key: (e.value.displayName?.isNotEmpty ?? false)
                      ? e.value.displayName!
                      : e.value.email,
              },
            );
            final canMutate =
                uid == expense.payerId || event.can(uid, 'money.record');
            final repo = ref.watch(expenseRepositoryProvider);

            if (_editing && canMutate && !expense.isPayment) {
              return ExpenseModal(
                eventId: event.id,
                payerId: expense.payerId,
                memberIds: event.memberIds,
                words: event.words,
                currencySymbol: symbol,
                initial: expense,
                onCancel: () => setState(() => _editing = false),
                onSubmit: (updated, _) => repo.saveExpense(updated),
              );
            }

            return ExpenseDetailScreen(
              expense: expense,
              event: event,
              currencySymbol: symbol,
              mine: expense.payerId == uid,
              payerName: nameOf(expense.payerId),
              payeeName: payee == null
                  ? null
                  : (payee == uid ? s.you : nameOf(payee)),
              onEdit: canMutate && !expense.isPayment
                  ? () => setState(() => _editing = true)
                  : null,
              onDelete: canMutate ? () => _delete(expense) : null,
            );
          },
          loading: () => bare(
            CpLoadingState(
              key: const Key('budget.expense.loading'),
              semanticLabel: s.expenseWord,
            ),
          ),
          error: (e, _) => bare(
            CpErrorState(
              title: s.loadFailed,
              message: userMessageFor(
                e,
                strings: context.strings.errors,
                fallback: context.strings.errors.genericFallback,
              ),
              retryLabel: context.strings.people.retry,
              retryKey: const Key('budget.expense.retry'),
              onRetry: () => ref.invalidate(expenseListProvider(event.id)),
            ),
          ),
        );
  }
}
