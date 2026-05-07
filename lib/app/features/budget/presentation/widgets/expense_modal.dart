import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

/// Submit signature: receives the expense model AND the picked receipt
/// (if any). The parent uploads the bytes out-of-band so the modal stays
/// free of Firebase / Storage coupling. Web-safe — no `dart:io File`.
typedef ExpenseSubmit =
    void Function(ExpenseModel expense, PickedImage? receipt);

/// Async receipt picker callback — returns null if the user cancels.
typedef ReceiptPicker = Future<PickedImage?> Function();

class ExpenseModal extends StatefulWidget {
  const ExpenseModal({
    super.key,
    required this.eventId,
    required this.payerId,
    required this.memberIds,
    this.currencySymbol = '\$',
    this.minAmount = 0.01,
    this.maxAmount = 10000000,
    this.onPickReceipt,
    this.onSubmit,
  });

  final String eventId;
  final String payerId;
  final List<String> memberIds;
  final String currencySymbol;
  final double minAmount;
  final double maxAmount;
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
    String currencySymbol = '\$',
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
        currencySymbol: currencySymbol,
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
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isDonation = false;
  PickedImage? _pickedReceipt;

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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final splits = ExpenseModel.calculateSplits(
      amount: amount,
      payerId: widget.payerId,
      memberIds: widget.memberIds,
      isDonation: _isDonation,
    );

    final expense = ExpenseModel(
      id: const Uuid().v4(),
      eventId: widget.eventId,
      payerId: widget.payerId,
      amount: amount,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isDonation: _isDonation,
      splits: splits,
    );

    widget.onSubmit?.call(expense, _pickedReceipt);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final splitCount = _isDonation
        ? widget.memberIds.where((id) => id != widget.payerId).length
        : widget.memberIds.length;
    final splitAmount = splitCount > 0 ? amount / splitCount : 0.0;
    final canPickReceipt = widget.onPickReceipt != null;

    return Padding(
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
            Text('Add Expense', style: Theme.of(context).textTheme.titleLarge),
            CustomTextField(
              key: const Key('budget.expense.amount'),
              hintText: 'Amount (${widget.currencySymbol})',
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: const Icon(Icons.attach_money),
              onChanged: (_) => setState(() {}),
              validator: (value) => ExpenseModal.validateAmountInput(
                value,
                minAmount: widget.minAmount,
                maxAmount: widget.maxAmount,
              ),
            ),
            CustomTextField(
              hintText: 'Description (optional)',
              controller: _descriptionController,
              prefixIcon: const Icon(Icons.description),
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
                  onChanged: (value) => setState(() => _isDonation = value),
                  activeThumbColor: AppColors.sage,
                ),
              ],
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGrey),
              ),
            PrimaryButton(
              key: const Key('budget.expense.save'),
              label: 'Add Expense',
              onPressed: _submit,
            ),
          ],
        ),
      ),
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
        icon: const Icon(Icons.camera_alt_outlined),
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
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
        const Expanded(child: Text('Receipt attached')),
        IconButton(
          key: const Key('budget.expense.receipt.clear'),
          onPressed: onClear,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
