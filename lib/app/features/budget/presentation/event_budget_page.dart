import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/layout/cp_list_detail.dart';
import 'package:crewpoint_app/app/features/budget/application/budget_list_controller.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/budget_summary.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/app_lifecycle_source.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/budget/application/pending_settlement_notifier.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_export_pipeline.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';
import 'package:crewpoint_app/app/features/budget/data/pay_link_builder.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/large_event.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/repositories/i_expense_repository.dart';
import 'package:crewpoint_app/app/features/budget/presentation/budget_screen.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_modal.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/settle_sheet.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// The event's Budget. Reads `expenseListProvider(eventId)` and routes
/// saving and the settle-up flow through the repository providers.
///
/// On an expense's route [detail] is that expense: from 840 px it shows
/// beside the list with [selectedId] chosen, and narrower it is the whole
/// page (Spec #186 Req 23).
class EventBudgetPage extends ConsumerStatefulWidget {
  const EventBudgetPage({
    super.key,
    required this.event,
    this.selectedId,
    this.detail,
  });

  final EventModel event;
  final String? selectedId;
  final Widget? detail;

  @override
  ConsumerState<EventBudgetPage> createState() => _EventBudgetPageState();
}

class _EventBudgetPageState extends ConsumerState<EventBudgetPage> {
  late final WidgetsAppLifecycleSource _lifecycleSource;
  late final PendingSettlementNotifier _pending;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(initialScrollOffset: _list.scrollOffset);
    _scroll.addListener(() {
      if (mounted && _scroll.hasClients) _list.scrollOffset = _scroll.offset;
    });
    _lifecycleSource = WidgetsAppLifecycleSource();
    _pending = PendingSettlementNotifier(
      launcher: ref.read(urlLauncherProvider),
      lifecycleSource: _lifecycleSource,
    );
    _pending.onConfirmRequested = _handleConfirmRequested;
  }

  /// Read fresh each time, never in dispose: the provider is rebuilt when
  /// no list has watched it for a while.
  BudgetListController get _list =>
      ref.read(budgetListProvider(widget.event.id).notifier);

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _open(ExpenseModel expense) {
    final path = '/dashboard/event/${widget.event.id}/budget/${expense.id}';
    if (CpListDetail.isSplit(context)) {
      context.go(path);
    } else {
      context.push(path);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pending.dispose();
    _lifecycleSource.dispose();
    super.dispose();
  }

  String _currencySymbol(String code) => currencySymbolFor(code);

  /// The payee's handles, from the event's profiles: only people who share
  /// an event can see them (Req 37).
  Future<({String? venmoHandle, String? cashappHandle, String? displayName})>
  _fetchPayeeProfile(String uid) async {
    try {
      final payee = await ref
          .read(userRepositoryProvider)
          .watchEventProfile(widget.event.id, uid)
          .first;
      return (
        venmoHandle: payee?.venmoHandle,
        cashappHandle: payee?.cashappHandle,
        displayName: payee?.displayName,
      );
    } catch (_) {
      return (venmoHandle: null, cashappHandle: null, displayName: null);
    }
  }

  Future<void> _onSettlePressed(Settlement settlement) async {
    final auth = ref.read(authProvider);
    if (auth is! Authenticated) return;
    final myUid = auth.user.uid;

    final event = widget.event;
    final involvesDeparted =
        !event.isMember(settlement.fromUserId) ||
        !event.isMember(settlement.toUserId);
    if (involvesDeparted) {
      await _settleForDeparted(
        settlement,
        canRecord: event.can(myUid, 'money.record'),
      );
      return;
    }

    // V1: only show the sheet when the current user is the payer.
    if (settlement.fromUserId != myUid) return;

    final payee = await _fetchPayeeProfile(settlement.toUserId);
    if (!mounted) return;
    final symbol = _currencySymbol(widget.event.currency);

    await SettleSheet.show(
      context: context,
      settlement: settlement,
      currencySymbol: symbol,
      fromName: context.strings.budget.youCapital,
      toName: payee.displayName,
      venmoHandle: payee.venmoHandle,
      cashappHandle: payee.cashappHandle,
      onPayVenmo: payee.venmoHandle == null
          ? null
          : () {
              Navigator.of(context).pop();
              _launchVenmo(settlement, payee.venmoHandle!);
            },
      onPayCashApp: payee.cashappHandle == null
          ? null
          : () {
              Navigator.of(context).pop();
              _launchCashApp(settlement, payee.cashappHandle!);
            },
      onCopyDetails: () {
        Navigator.of(context).pop();
        final s = context.strings.budget;
        final details = s.copyDetailsText(
          '$symbol${settlement.amount.toStringAsFixed(2)}',
          payee.displayName ?? settlement.toUserId,
          widget.event.title,
        );
        Clipboard.setData(ClipboardData(text: details));
        _say(s.copiedDetails);
      },
    );
  }

  /// Someone who has left cannot use a pay link, so `money.record` holders
  /// record the payment directly. Owners and admins hold it until permissions
  /// land.
  Future<void> _settleForDeparted(
    Settlement settlement, {
    required bool canRecord,
  }) async {
    final strings = context.strings.budget;
    if (!canRecord) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.settleOnBehalfNeedsOrganizer)),
      );
      return;
    }
    final names = await _namesFor(settlement);
    if (!mounted) return;
    final symbol = _currencySymbol(widget.event.currency);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => CpDialog(
        title: strings.settleOnBehalfTitle,
        message: strings.settleOnBehalfBody(
          '$symbol${settlement.amount.toStringAsFixed(2)}',
          names.from,
          names.to,
        ),
        actions: [
          CpButton.text(
            key: const Key('budget.settle.onBehalf.cancel'),
            label: strings.settleOnBehalfCancel,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CpButton(
            key: const Key('budget.settle.onBehalf.confirm'),
            label: strings.settleOnBehalfConfirm,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final repo = ref.read(expenseRepositoryProvider);
    await _recordSettlement(
      payerId: settlement.fromUserId,
      payeeId: settlement.toUserId,
      amount: settlement.amount,
      settlementId: repo.newSettlementId(widget.event.id),
    );
  }

  /// Names of the payers and of the balances and transfers shown, read
  /// one by one, never the whole event (Req 43a).
  AsyncValue<Map<String, AppUser>> _names(
    String uid,
    List<ExpenseModel> expenses,
  ) {
    final event = widget.event;
    final limited = !event.readsAllExpenses(uid);
    final ledger = limited
        ? ref.watch(myBalanceProvider(event.id)).value?.toLedger(uid, expenses)
        : BalanceLedger.calculate(
            expenses: expenses,
            memberIds: event.memberIds,
          );
    return ref.watch(
      peopleByIdProvider(
        PeopleKey(event.id, [
          for (final e in expenses) e.payerId,
          if (ledger != null)
            ...budgetNameUids(
              expenses: expenses,
              ledger: ledger,
              me: uid,
              memberCount: event.memberIds.length,
            ),
        ]),
      ),
    );
  }

  Future<({String from, String to})> _namesFor(Settlement settlement) async {
    final users = await fetchPeople(
      ref.read(userRepositoryProvider),
      widget.event.id,
      [settlement.fromUserId, settlement.toUserId],
    );
    String nameOf(String uid) => resolveMemberName(
      uid: uid,
      memberNames: {
        for (final entry in users.entries)
          entry.key: entry.value.displayName ?? entry.value.email,
      },
    );
    return (
      from: nameOf(settlement.fromUserId),
      to: nameOf(settlement.toUserId),
    );
  }

  Future<void> _launchVenmo(Settlement settlement, String handle) async {
    final note = '${widget.event.title} settle';
    Uri uri;
    try {
      uri = PayLinkBuilder.venmo(
        handle: handle,
        amount: settlement.amount,
        note: note,
      );
    } on ArgumentError {
      _showInvalidHandleSnackbar();
      return;
    }
    final auth = ref.read(authProvider);
    if (auth is! Authenticated) return;
    final ok = await _pending.launchAndPrepare(
      uri,
      payerId: auth.user.uid,
      payeeId: settlement.toUserId,
      amount: settlement.amount,
    );
    if (!ok) {
      // Fall back to web URL.
      final web = PayLinkBuilder.venmoWebFallback(
        handle: handle,
        amount: settlement.amount,
        note: note,
      );
      await _pending.launchAndPrepare(
        web,
        payerId: auth.user.uid,
        payeeId: settlement.toUserId,
        amount: settlement.amount,
      );
    }
  }

  Future<void> _launchCashApp(Settlement settlement, String handle) async {
    Uri uri;
    try {
      uri = PayLinkBuilder.cashApp(handle: handle, amount: settlement.amount);
    } on ArgumentError {
      _showInvalidHandleSnackbar();
      return;
    }
    final auth = ref.read(authProvider);
    if (auth is! Authenticated) return;
    await _pending.launchAndPrepare(
      uri,
      payerId: auth.user.uid,
      payeeId: settlement.toUserId,
      amount: settlement.amount,
    );
  }

  void _showInvalidHandleSnackbar() {
    if (!mounted) return;
    _say(context.strings.budget.invalidHandle);
  }

  Future<void> _runExport({
    required List<ExpenseModel> expenses,
    required Map<String, String> memberNames,
    required ExpenseExportKind kind,
    BalanceLedger? ledger,
  }) async {
    try {
      // The report names everyone in its balances and transfers, not only
      // the rows on screen, so those names are read now (Req 43a).
      final full =
          ledger ??
          BalanceLedger.calculate(
            expenses: expenses,
            memberIds: widget.event.memberIds,
          );
      final missing = {
        ...full.netBalances.keys,
        for (final s in full.settlements) ...[s.fromUserId, s.toUserId],
      }.difference(memberNames.keys.toSet());
      final extra = missing.isEmpty
          ? const <String, AppUser>{}
          : await fetchPeople(
              ref.read(userRepositoryProvider),
              widget.event.id,
              missing,
            );
      await runExpenseExport(
        event: widget.event,
        expenses: expenses,
        memberNames: {
          ...memberNames,
          for (final p in extra.values)
            if (p.displayName?.isNotEmpty ?? false) p.uid: p.displayName!,
        },
        exporter: ref.read(fileExporterProvider),
        kind: kind,
        ledger: ledger,
      );
    } catch (_) {
      if (!mounted) return;
      _say(context.strings.budget.exportFailed);
    }
  }

  Future<void> _handleConfirmRequested(PendingSettlement pending) async {
    if (!mounted) return;
    final symbol = _currencySymbol(widget.event.currency);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final s = ctx.strings.budget;
        return CpDialog(
          title: s.confirmSentTitle,
          message: s.confirmSentBody(
            '$symbol${pending.amount.toStringAsFixed(2)}',
          ),
          actions: [
            CpButton.text(
              key: const Key('budget.settle.confirm.no'),
              label: s.notYet,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            CpButton(
              key: const Key('budget.settle.confirm'),
              label: s.yesRecorded,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );
    _pending.clearPending();
    if (confirmed != true) return;

    final repo = ref.read(expenseRepositoryProvider);
    await _recordSettlement(
      payerId: pending.payerId,
      payeeId: pending.payeeId,
      amount: pending.amount,
      settlementId: repo.newSettlementId(widget.event.id),
    );
  }

  /// Records a confirmed payment, and offers retry with the same [settlementId]
  /// when there is no connection, so it can never be recorded twice.
  Future<void> _recordSettlement({
    required String payerId,
    required String payeeId,
    required double amount,
    required String settlementId,
  }) async {
    final result = await ref
        .read(expenseRepositoryProvider)
        .recordSettlement(
          eventId: widget.event.id,
          settlementId: settlementId,
          payerId: payerId,
          payeeId: payeeId,
          amount: amount,
        );
    if (result == ExpenseSaveResult.saved || !mounted) return;
    final strings = context.strings.budget;
    final needsConnection = result == ExpenseSaveResult.needsConnection;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('budget.settle.error'),
        content: Text(
          needsConnection
              ? strings.settlementNeedsConnection
              : strings.settlementRejected,
        ),
        action: needsConnection
            ? SnackBarAction(
                key: const Key('budget.settle.retry'),
                label: strings.expenseRetry,
                onPressed: () => _recordSettlement(
                  payerId: payerId,
                  payeeId: payeeId,
                  amount: amount,
                  settlementId: settlementId,
                ),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Narrower than 840 px an expense's route is the expense alone.
    final detail = widget.detail;
    if (detail != null && !CpListDetail.isSplit(context)) return detail;

    final s = context.strings.budget;
    final auth = ref.watch(authProvider);
    final uid = auth is Authenticated ? auth.user.uid : null;
    Widget bare(Widget body) => Scaffold(
      appBar: CpTopBar(
        title: widget.event.title,
        leadingKey: const Key('budget.back'),
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: () => Navigator.of(context).maybePop(),
      ),
      body: body,
    );
    if (uid == null) {
      return bare(CpEmptyState(icon: CpIcons.lock, title: s.signInRequired));
    }

    // Kept while the list shows, so its scroll place survives a choice.
    ref.watch(budgetListProvider(widget.event.id));
    final asyncExpenses = ref.watch(expenseListProvider(widget.event.id));
    final repo = ref.watch(expenseRepositoryProvider);
    final imageService = ref.watch(imageServiceProvider);
    final symbol = _currencySymbol(widget.event.currency);

    return asyncExpenses.when(
      data: (expenses) {
        // Prefer displayName, fall back to email when not set.
        final memberNames = _names(uid, expenses).maybeWhen(
          data: (users) => {
            for (final entry in users.entries)
              entry.key: () {
                final name = entry.value.displayName;
                if (name != null && name.isNotEmpty) return name;
                if (entry.value.email.isNotEmpty) return entry.value.email;
                return '';
              }(),
          },
          orElse: () => <String, String>{},
        );

        // Someone who may not read every expense sees their own balance from
        // the server, worked out from all of them (Req 38c).
        final limited = !widget.event.readsAllExpenses(uid);
        final serverBalance = limited
            ? ref.watch(myBalanceProvider(widget.event.id)).value
            : null;
        final ledger = limited
            ? (serverBalance?.toLedger(uid, expenses) ??
                  // Until the server answers: the total they can read,
                  // and no balances.
                  BalanceLedger(
                    netBalances: const {},
                    settlements: const [],
                    totalExpenses: BalanceLedger.calculate(
                      expenses: expenses,
                      memberIds: const [],
                    ).totalExpenses,
                  ))
            : null;
        return BudgetScreen(
          ledger: ledger,
          expenses: expenses,
          memberIds: widget.event.memberIds,
          currentUserId: uid,
          currency: widget.event.currency,
          // Observers and Vendors cannot add expenses (Req 34).
          canAddExpense:
              widget.event.allowsChatAndMoney && widget.event.contributes(uid),
          memberNames: memberNames,
          appBarTitle: widget.event.title,
          selectedId: widget.selectedId,
          detail: detail,
          scrollController: _scroll,
          inZone: widget.event.inZone,
          onOpenExpense: _open,
          onBack: () => Navigator.of(context).maybePop(),
          onRecordPayment: _onSettlePressed,
          onExportPdf: () => _runExport(
            expenses: expenses,
            memberNames: memberNames,
            kind: ExpenseExportKind.pdf,
            ledger: ledger,
          ),
          onExportCsv: () => _runExport(
            expenses: expenses,
            memberNames: memberNames,
            kind: ExpenseExportKind.csv,
          ),
          onAddExpense: () => ExpenseModal.show(
            context: context,
            eventId: widget.event.id,
            payerId: uid,
            memberIds: widget.event.memberIds,
            words: widget.event.words,
            currencySymbol: symbol,
            onPickReceipt: () => imageService.pickFromGallery(
              maxWidth: 1600,
              maxHeight: 1600,
              quality: 70,
            ),
            onSubmit: (expense, receipt) async {
              String? receiptUrl;
              if (receipt != null) {
                receiptUrl = await repo.uploadReceipt(
                  eventId: widget.event.id,
                  expenseId: expense.id,
                  bytes: receipt.bytes,
                  contentType: receipt.contentType,
                );
              }
              final result = await repo.saveExpense(
                expense.copyWith(receiptPath: receiptUrl),
              );
              // Only said once saved: when the save fails too, the form stays
              // open with the receipt and a retry uploads it again.
              final savedWithoutReceipt =
                  result == ExpenseSaveResult.saved &&
                  receipt != null &&
                  receiptUrl == null;
              if (savedWithoutReceipt && context.mounted) {
                _say(s.receiptUploadFailed);
              }
              return result;
            },
          ),
        );
      },
      loading: () => bare(
        CpLoadingState.rows(
          key: const Key('budget.loading'),
          semanticLabel: s.title,
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
          retryKey: const Key('budget.retry'),
          onRetry: () => ref.invalidate(expenseListProvider(widget.event.id)),
        ),
      ),
    );
  }
}
