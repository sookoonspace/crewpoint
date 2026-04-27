import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:uuid/uuid.dart';

class ExpenseModal extends StatefulWidget {
  const ExpenseModal({
    super.key,
    required this.eventId,
    required this.payerId,
    required this.memberIds,
    this.currencySymbol = '\$',
    this.minAmount = 0.01,
    this.maxAmount = 10000000,
    this.onSubmit,
  });

  final String eventId;
  final String payerId;
  final List<String> memberIds;
  final String currencySymbol;
  final double minAmount;
  final double maxAmount;
  final ValueChanged<ExpenseModel>? onSubmit;

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
    ValueChanged<ExpenseModel>? onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExpenseModal(
        eventId: eventId,
        payerId: payerId,
        memberIds: memberIds,
        currencySymbol: currencySymbol,
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

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

    widget.onSubmit?.call(expense);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final splitCount = _isDonation
        ? widget.memberIds.where((id) => id != widget.payerId).length
        : widget.memberIds.length;
    final splitAmount = splitCount > 0 ? amount / splitCount : 0.0;

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
