import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/large_event.dart';
import 'package:crewpoint_app/app/features/budget/domain/repositories/i_expense_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/member_picker_sheet.dart';

/// Submit signature: receives the expense model AND the picked receipt
/// (if any). The parent uploads the bytes out-of-band so the modal stays
/// free of Firebase / Storage coupling. Web-safe — no `dart:io File`.
///
/// The form stays open until this reports [ExpenseSaveResult.saved], so what
/// was entered survives a failure.
typedef ExpenseSubmit =
    Future<ExpenseSaveResult> Function(
      ExpenseModel expense,
      PickedImage? receipt,
    );

/// Async receipt picker callback — returns null if the user cancels.
typedef ReceiptPicker = Future<PickedImage?> Function();

class ExpenseModal extends StatefulWidget {
  const ExpenseModal({
    super.key,
    required this.eventId,
    required this.payerId,
    required this.memberIds,
    this.words = const LabelResolver({}),
    this.currencySymbol = '\$',
    this.minAmount = 0.01,
    this.maxAmount = 10000000,
    this.initial,
    this.onPickReceipt,
    this.onSubmit,
  });

  final String eventId;
  final String payerId;
  final List<String> memberIds;

  /// The event's words, for the member picker.
  final LabelResolver words;
  final String currencySymbol;
  final double minAmount;
  final double maxAmount;

  /// When non-null, the modal opens in edit mode: pre-fills from this
  /// model, locks `payerId` (display-only), preserves the id on submit,
  /// and renders `Save changes` instead of `Add Expense`.
  final ExpenseModel? initial;
  final ReceiptPicker? onPickReceipt;
  final ExpenseSubmit? onSubmit;

  /// Validates amount-string then bounds. Returns null if valid; else error msg.
  static String? validateAmountInput(
    String? raw, {
    double minAmount = 0.01,
    double maxAmount = 10000000,
  }) {
    if (raw == null || raw.trim().isEmpty) return 'Enter an amount';
    final value = double.tryParse(raw.trim());
    if (value == null) return 'Invalid amount';
    if (value < minAmount) return 'Amount must be at least $minAmount';
    if (value > maxAmount) return 'Amount must be at most $maxAmount';
    return null;
  }

  /// Returns null if splits sum is within `tolerance` of `total`; else error.
  static String? validateSplitSum(
    Iterable<ExpenseSplit> splits,
    double total, {
    double tolerance = 0.01,
  }) {
    final sum = splits.fold<double>(0, (acc, s) => acc + s.amount);
    if ((sum - total).abs() > tolerance) {
      return 'Split sum (${sum.toStringAsFixed(2)}) must equal total '
          '(${total.toStringAsFixed(2)})';
    }
    return null;
  }

  static Future<void> show({
    required BuildContext context,
    required String eventId,
    required String payerId,
    required List<String> memberIds,
    LabelResolver words = const LabelResolver({}),
    String currencySymbol = '\$',
    ExpenseModel? initial,
    ReceiptPicker? onPickReceipt,
    ExpenseSubmit? onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExpenseModal(
        eventId: eventId,
        payerId: payerId,
        memberIds: memberIds,
        words: words,
        currencySymbol: currencySymbol,
        initial: initial,
        onPickReceipt: onPickReceipt,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<ExpenseModal> createState() => _ExpenseModalState();
}

class _ExpenseModalState extends State<ExpenseModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late bool _isDonation;
  PickedImage? _pickedReceipt;
  bool _saving = false;
  ExpenseSaveResult? _failure;

  /// Who shares the cost, or null for everyone (Req 43a).
  Set<String>? _chosen;
  bool _splitError = false;
  bool _changed = false;

  /// Kept across retries, so a save that reached the server is not duplicated.
  final String _newExpenseId = const Uuid().v4();

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _amountController = TextEditingController(
      text: initial != null ? initial.amount.toString() : '',
    );
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _isDonation = initial?.isDonation ?? false;
    _chosen = _initialChoice();
  }

  /// Editing starts from who shared the expense, or everyone when it has no
  /// splits saved. A new one is split with
  /// everyone, except past 50 members, where people must be chosen.
  Set<String>? _initialChoice() {
    final initial = widget.initial;
    if (initial == null) {
      return splitNeedsChoosing(widget.memberIds.length) ? <String>{} : null;
    }
    // An expense saved without its splits was shared with everyone.
    if (initial.splits.isEmpty) return null;
    final shared = {
      for (final s in initial.splits) s.userId,
      if (initial.isDonation) initial.payerId,
    };
    final everyone = widget.memberIds.toSet();
    return shared.length == everyone.length && shared.containsAll(everyone)
        ? null
        : shared;
  }

  /// Who the amount is divided between, in member order where possible.
  List<String> get _splitters {
    final chosen = _chosen;
    final pool = chosen == null
        ? widget.memberIds
        : [
            for (final id in widget.memberIds)
              if (chosen.contains(id)) id,
            for (final id in chosen)
              if (!widget.memberIds.contains(id)) id,
          ];
    return _isDonation
        ? pool.where((id) => id != widget.payerId).toList()
        : pool;
  }

  Future<void> _choosePeople() async {
    final picked = await MemberPickerSheet.pickMany(
      context,
      eventId: widget.eventId,
      words: widget.words,
      initial: _chosen ?? widget.memberIds.toSet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _chosen = picked;
      _changed = true;
      _splitError = false;
    });
  }

  Future<void> _confirmLeave() async {
    final navigator = Navigator.of(context);
    if (await confirmDiscard(context)) navigator.pop();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final picker = widget.onPickReceipt;
    if (picker == null) return;
    final picked = await picker();
    if (!mounted || picked == null) return;
    setState(() => _pickedReceipt = picked);
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    final splitOk = _splitters.isNotEmpty;
    setState(() => _splitError = !splitOk);
    if (_saving || !formOk || !splitOk) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final splits = ExpenseModel.calculateSplits(
      amount: amount,
      payerId: widget.payerId,
      memberIds: _splitters,
      isDonation: false,
    );

    final initial = widget.initial;
    final expense = ExpenseModel(
      id: initial?.id ?? _newExpenseId,
      eventId: widget.eventId,
      payerId: widget.payerId,
      amount: amount,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isDonation: _isDonation,
      isPayment: initial?.isPayment ?? false,
      splits: splits,
      receiptPath: initial?.receiptPath,
      createdAt: initial?.createdAt,
    );

    final onSubmit = widget.onSubmit;
    if (onSubmit == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = true;
      _failure = null;
    });
    ExpenseSaveResult result;
    try {
      result = await onSubmit(expense, _pickedReceipt);
    } catch (e, st) {
      log('Expense submit failed', error: e, stackTrace: st, name: 'budget');
      result = ExpenseSaveResult.rejected;
    }
    if (!mounted) return;
    if (result == ExpenseSaveResult.saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _failure = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final splitCount = _splitters.length;
    final pickerStrings = context.strings.memberPicker;
    final chosen = _chosen;
    final splitAmount = splitCount > 0 ? amount / splitCount : 0.0;
    final canPickReceipt = widget.onPickReceipt != null;
    final strings = context.strings.budget;

    return PopScope(
      canPop: !_changed || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.xl,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            spacing: AppSpacing.lg,
            children: [
              Text(
                _isEdit ? 'Edit Expense' : 'Add Expense',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              CustomTextField(
                key: const Key('budget.expense.amount'),
                hintText: 'Amount (${widget.currencySymbol})',
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: const Icon(AppIcons.currency),
                onChanged: (_) => setState(() => _changed = true),
                validator: (value) => ExpenseModal.validateAmountInput(
                  value,
                  minAmount: widget.minAmount,
                  maxAmount: widget.maxAmount,
                ),
              ),
              CustomTextField(
                hintText: 'Description (optional)',
                controller: _descriptionController,
                prefixIcon: const Icon(AppIcons.description),
                onChanged: (_) => _changed = true,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Donate this cost',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Switch(
                    value: _isDonation,
                    onChanged: (value) => setState(() {
                      _isDonation = value;
                      _changed = true;
                    }),
                    activeThumbColor: AppColors.sage,
                  ),
                ],
              ),
              _SplitSection(
                heading: pickerStrings.splitHeading,
                summary: chosen == null
                    ? pickerStrings.splitEveryone(widget.memberIds.length)
                    : pickerStrings.splitChosen(chosen.length),
                mustChoose:
                    chosen != null &&
                        chosen.isEmpty &&
                        splitNeedsChoosing(widget.memberIds.length)
                    ? pickerStrings.splitMustChoose(largeEventMembers)
                    : null,
                error: _splitError ? pickerStrings.splitNoneChosen : null,
                chooseLabel: pickerStrings.choosePeople,
                everyoneLabel: chosen == null
                    ? null
                    : pickerStrings.splitUseEveryone,
                onChoose: _saving ? null : _choosePeople,
                onEveryone: () => setState(() {
                  _chosen = null;
                  _changed = true;
                  _splitError = false;
                }),
              ),
              if (canPickReceipt)
                _ReceiptRow(
                  receipt: _pickedReceipt,
                  onPick: _pickReceipt,
                  onClear: () => setState(() => _pickedReceipt = null),
                ),
              if (amount > 0)
                Text(
                  'Split: ${widget.currencySymbol}${splitAmount.toStringAsFixed(2)} per person ($splitCount people)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (_failure != null)
                Text(
                  _failure == ExpenseSaveResult.needsConnection
                      ? strings.expenseNeedsConnection
                      : strings.expenseSaveRejected,
                  key: const Key('budget.expense.error'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              PrimaryButton(
                key: const Key('budget.expense.save'),
                label: _failure == ExpenseSaveResult.needsConnection
                    ? strings.expenseRetry
                    : (_isEdit ? 'Save changes' : 'Add Expense'),
                isLoading: _saving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Who shares the cost: everyone, or the people chosen in the picker.
class _SplitSection extends StatelessWidget {
  const _SplitSection({
    required this.heading,
    required this.summary,
    required this.chooseLabel,
    required this.onChoose,
    required this.onEveryone,
    this.everyoneLabel,
    this.mustChoose,
    this.error,
  });

  final String heading;
  final String summary;
  final String chooseLabel;
  final String? everyoneLabel;
  final String? mustChoose;
  final String? error;
  final VoidCallback? onChoose;
  final VoidCallback onEveryone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('budget.expense.split'),
      crossAxisAlignment: .start,
      spacing: AppSpacing.xs,
      children: [
        Text(heading, style: theme.textTheme.titleSmall),
        Text(summary, key: const Key('budget.expense.split.summary')),
        if (mustChoose != null)
          Text(
            mustChoose!,
            key: const Key('budget.expense.split.mustChoose'),
            style: theme.textTheme.bodySmall,
          ),
        if (error != null)
          Text(
            error!,
            key: const Key('budget.expense.split.error'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              key: const Key('budget.expense.split.choose'),
              onPressed: onChoose,
              icon: const Icon(AppIcons.members),
              label: Text(chooseLabel),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
            if (everyoneLabel != null)
              TextButton(
                key: const Key('budget.expense.split.everyone'),
                onPressed: onEveryone,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(everyoneLabel!),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.receipt,
    required this.onPick,
    required this.onClear,
  });

  final PickedImage? receipt;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    if (r == null) {
      return OutlinedButton.icon(
        key: const Key('budget.expense.receipt.add'),
        onPressed: onPick,
        icon: const Icon(AppIcons.camera),
        label: const Text('Add receipt'),
      );
    }

    return Row(
      key: const Key('budget.expense.receipt.preview'),
      spacing: AppSpacing.md,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            r.bytes,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 56,
              height: 56,
              color: AppColors.lightGrey,
              child: const Icon(AppIcons.imageBroken),
            ),
          ),
        ),
        const Expanded(child: Text('Receipt attached')),
        IconButton(
          key: const Key('budget.expense.receipt.clear'),
          onPressed: onClear,
          icon: const Icon(AppIcons.actionClose),
        ),
      ],
    );
  }
}
