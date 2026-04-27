import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/app_lifecycle_source.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/budget/application/pending_settlement_notifier.dart';
import 'package:crewpoint_app/app/features/budget/data/pay_link_builder.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/presentation/budget_screen.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_modal.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/settle_sheet.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Event-scoped budget page. Reads `expenseListProvider(eventId)` and routes
/// mutations + settlement flow through the repository providers.
class EventBudgetPage extends ConsumerStatefulWidget {
  const EventBudgetPage({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<EventBudgetPage> createState() => _EventBudgetPageState();
}

class _EventBudgetPageState extends ConsumerState<EventBudgetPage> {
  late final WidgetsAppLifecycleSource _lifecycleSource;
  late final PendingSettlementNotifier _pending;

  @override
  void initState() {
    super.initState();
    _lifecycleSource = WidgetsAppLifecycleSource();
    _pending = PendingSettlementNotifier(
      launcher: ref.read(urlLauncherProvider),
      lifecycleSource: _lifecycleSource,
    );
    _pending.onConfirmRequested = _handleConfirmRequested;
  }

  @override
  void dispose() {
    _pending.dispose();
    _lifecycleSource.dispose();
    super.dispose();
  }

  String _currencySymbol(String code) => switch (code) {
    'USD' || 'CAD' || 'AUD' => '\$',
    'EUR' => '€',
    'GBP' => '£',
    'JPY' => '¥',
    'INR' => '₹',
    _ => '\$',
  };

  Future<({String? venmoHandle, String? cashappHandle, String? displayName})>
  _fetchPayeeProfile(String uid) async {
    try {
      final doc = await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      return (
        venmoHandle: data?['venmoHandle'] as String?,
        cashappHandle: data?['cashappHandle'] as String?,
        displayName: data?['displayName'] as String?,
      );
    } catch (_) {
      return (venmoHandle: null, cashappHandle: null, displayName: null);
    }
  }

  Future<void> _onSettlePressed(Settlement settlement) async {
    final auth = ref.read(authProvider);
    if (auth is! Authenticated) return;
    final myUid = auth.user.uid;
    // V1: only show the sheet when the current user is the payer.
    if (settlement.fromUserId != myUid) return;

    final payee = await _fetchPayeeProfile(settlement.toUserId);
    if (!mounted) return;
    final symbol = _currencySymbol(widget.event.currency);

    await SettleSheet.show(
      context: context,
      settlement: settlement,
      currencySymbol: symbol,
      fromName: 'You',
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
        final details =
            '$symbol${settlement.amount.toStringAsFixed(2)} '
            'to ${payee.displayName ?? settlement.toUserId} '
            'for ${widget.event.title}';
        Clipboard.setData(ClipboardData(text: details));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied — paste it where you settle')),
        );
      },
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('That payment handle looks invalid'),
        backgroundColor: AppColors.terracotta,
      ),
    );
  }

  Future<void> _handleConfirmRequested(PendingSettlement pending) async {
    if (!mounted) return;
    final symbol = _currencySymbol(widget.event.currency);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Did you send the payment?'),
        content: Text(
          'Did you send $symbol${pending.amount.toStringAsFixed(2)}? '
          'We\'ll record it in the budget so the ledger balances.',
        ),
        actions: [
          TextButton(
            key: const Key('budget.settle.confirm.no'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            key: const Key('budget.settle.confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, recorded'),
          ),
        ],
      ),
    );
    _pending.clearPending();
    if (confirmed != true) return;

    final repo = ref.read(expenseRepositoryProvider);
    final id = await repo.recordSettlement(
      eventId: widget.event.id,
      payerId: pending.payerId,
      payeeId: pending.payeeId,
      amount: pending.amount,
    );
    if (id == null) return;

    final chat = ref.read(chatRepositoryProvider);
    await chat.postSettlementNotice(
      eventId: widget.event.id,
      messageId: id,
      senderId: pending.payerId,
      text:
          'Settled $symbol${pending.amount.toStringAsFixed(2)} '
          'with a member',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final uid = auth is Authenticated ? auth.user.uid : null;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }

    final asyncExpenses = ref.watch(expenseListProvider(widget.event.id));
    final repo = ref.watch(expenseRepositoryProvider);
    final imageService = ref.watch(imageServiceProvider);
    final symbol = _currencySymbol(widget.event.currency);

    return asyncExpenses.when(
      data: (expenses) => BudgetScreen(
        expenses: expenses,
        memberIds: widget.event.memberIds,
        currency: widget.event.currency,
        onRecordPayment: _onSettlePressed,
        onAddExpense: () => ExpenseModal.show(
          context: context,
          eventId: widget.event.id,
          payerId: uid,
          memberIds: widget.event.memberIds,
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
                file: receipt,
              );
              if (receiptUrl == null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Receipt upload failed — saving expense without it',
                    ),
                    backgroundColor: AppColors.terracotta,
                  ),
                );
              }
            }
            final ok = await repo.createExpense(
              expense.copyWith(receiptPath: receiptUrl),
            );
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to add expense'),
                  backgroundColor: AppColors.terracotta,
                ),
              );
            }
          },
        ),
      ),
      loading: () => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('Budget'),
          backgroundColor: AppColors.cream,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('Budget'),
          backgroundColor: AppColors.cream,
          elevation: 0,
        ),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}
